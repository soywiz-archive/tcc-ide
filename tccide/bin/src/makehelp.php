<?php
	$shortdescs = array();
	$api = array();
	$api_cat = array();
	$pages = array();
	$keywords = array();

	function getCachedUrl($url) {
		$posix_file = preg_replace('/[^\\w\\d_-]+/i', '-', $url);
		@mkdir('cache', 0777); $file = "cache/{$posix_file}";
		if (!file_exists($file)) file_put_contents($file, file_get_contents($url));
		return file_get_contents($file);
	}

	function stripHtml($html) {
		return trim(preg_replace('/\\s+/', ' ', html_entity_decode(strip_tags($html))));
	}

	function addShortDesc($url) {
		global $shortdescs;
		$ret = array();
		$html = getCachedUrl($url);
		// .*<td.*>(.*)</td>.*<td.*>(.*)</td>
		preg_match_all('@<tr class="category-table-tr-[12]">.*<td.*>(.*)</td>.*<td.*>(.*)</td>@msUi', $html, $matches);

		//print_r($matches); exit;

		unset($matches[0]);

		for ($n = 0, $l = sizeof($matches[1]); $n < $l; $n++) {
			list($rname, $desc) = array(
				stripHtml($matches[1][$n]),
				stripHtml($matches[2][$n])
			);

			foreach (explode(',', $rname) as $name) { $name = trim($name);
				if (strtolower(substr($name, 0, 4)) == 'and ') $name = trim(substr($name, 4));
				$shortdescs[$name] = $desc;
			}
		}
	}

	function replace_links($matches) {
		// $matches[0]; // all
		// $matches[1]; // link
		// $matches[2]; // text

		return '<strong>' . $matches[2] . '</strong>';
	}

	function ggn($a) {
		return str_replace('#', '_', $a);
	}

	function addApi($catid, $url, $mustList = true) {
		global $shortdescs;
		global $api;
		global $api_cat;
		global $keywords;

		$html = getCachedUrl($url);

		$title = preg_match('@<title.*>(.*)</title>@i', $html, $r) ? stripHtml($r[1]) : 'Unknown';
		$title = str_replace('C/C++', 'C', $title);

		$api_cat[$catid]['title'] = $title;

		$api_cat[$catid]['mustList'] = $mustList;

		$keywords[$catid] = $title;

		//echo $html;

		foreach (split('<hr>', $html) as $chunk) {
			if (!preg_match('@<div class="name-format">(.*)</div>@msUi', $chunk, $matches)) continue;
			$rname = stripHtml($matches[1]);

			preg_match('@<pre class="syntax-box">(.*)</pre>@msUi', $chunk, $matches);
			$use = $matches[1];

			preg_match('@<div class="related-content">(.*)</div>@msUi', $chunk, $matches);
			$related = @$matches[1];

			preg_match('@<pre class="syntax-box">.*</pre>(.*)^@msUi', $chunk, $matches);

			if (strpos($chunk, '<pre class="syntax-box">') !== false) {
				list(,$desc) = explode('<pre class="syntax-box">', $chunk, 2);
				list(,$desc) = explode('</pre>', $desc, 2);
			} else {
				list(,$desc) = explode('<div class="name-format">', $chunk, 2);
				list(,$desc) = explode('</div>', $desc, 2);
			}

			list($desc) = explode('<div class="related-name-format">', $desc, 2);

			$desc = preg_replace_callback('@<a.*href.*=.*"(.*)".*.*>(.*)</a>@msUi', 'replace_links', $desc);

			preg_match_all('@<a.*href.*=.*".*".*>(.*)</a>@msUi', $related, $lrelated);
			$related = array();
			foreach ($lrelated[1] as $crelated) {
				foreach (explode(',', $crelated) as $name) {
					if (strtolower(substr($name, 0, 4)) == 'and ') $name = trim(substr($name, 4));
					$related[] = $name;
				}
			}

			foreach (explode(',', $rname) as $name) { $name = trim($name);
				if (strtolower(substr($name, 0, 4)) == 'and ') $name = trim(substr($name, 4));

				$api_cat[$catid]['list'][$name] = $api[$name] = array(
					'file' => ggn($name) . '.html',
					'use' => $use,
					'desc' => $desc,
					'related' => $related,
					'shortdesc' => @$shortdescs[$name],
					'cat' => $title,
					'catid' => $catid,
					'mustList' => $mustList,
				);

				$keywords[$name] = $name;
			}
		}
	}

	function addSpecial($catid, $url) {
		global $pages;
		global $keywords;
		$html = getCachedUrl($url);

		$title = preg_match('@<title.*>(.*)</title>@i', $html, $r) ? stripHtml($r[1]) : 'Unknown';
		$title = str_replace('C/C++', 'C', $title);

		$keywords[$catid] = $title;

		list(,$html2) = explode('</h3>', $html, 2);
		if (!strlen($html2)) {
			list(,$html2) = explode('</h1>', $html, 2);
		}

		$html = $html2;

		list($html) = explode('<td width="120" valign="top">', $html, 2);

		$html = preg_replace_callback('@<a.*href.*=.*"(.*)".*>(.*)</a>@msUi', 'replace_links', $html);

		$pages[$catid] = array(
			'url' => $url,
			'html' => $html,
			'title' => $title,
		);
	}

	function copyApi($from, $to) {
		global $api, $api_cat, $keywords;

		$tocopy = $api[$from];
		$catid = $tocopy['catid'];
		$tocopy['file'] = ggn($to) . '.html';
		$api_cat[$catid]['list'][$to] = $api[$to] = $tocopy;

		$keywords[$to] = $keywords[$from];
	}

	function removeApi($rem) {
		global $api, $api_cat, $keywords;

		$capi = &$api[$rem];
		unset($api_cat[$capi['catid']]['list'][$rem]);
		unset($api[$rem]);

		unset($keywords[$rem]);
	}

	addSpecial('-precedence', 'http://www.cppreference.com/operator_precedence.html');
	addSpecial('-escape', 'http://www.cppreference.com/escape_sequences.html');
	addSpecial('-ascii', 'http://www.cppreference.com/ascii.html');
	addSpecial('-types', 'http://www.cppreference.com/data_types.html');

	addShortDesc('http://www.cppreference.com/all_c_functions.html');

	addShortDesc('http://www.cppreference.com/keywords/index.html');

	addApi('-stddate', 'http://www.cppreference.com/stddate/all.html');
	addApi('-stdstring', 'http://www.cppreference.com/stdstring/all.html');
	addApi('-stdio', 'http://www.cppreference.com/stdio/all.html');
	addApi('-stdmath', 'http://www.cppreference.com/stdmath/all.html');
	addApi('-stdmem', 'http://www.cppreference.com/stdmem/all.html');
	addApi('-stdother', 'http://www.cppreference.com/stdother/all.html');
	addApi('-preprocessor', 'http://www.cppreference.com/preprocessor/all.html', false);
	addApi('-keywords', 'http://www.cppreference.com/keywords/all.html', false);

	copyApi('Predefined preprocessor variables', '__LINE__');
	copyApi('Predefined preprocessor variables', '__FILE__');
	copyApi('Predefined preprocessor variables', '__DATE__');
	copyApi('Predefined preprocessor variables', '__TIME__');
	copyApi('Predefined preprocessor variables', '__cplusplus');
	copyApi('Predefined preprocessor variables', '__STDC__');

	removeApi('Predefined preprocessor variables');

	removeApi('bool');
	removeApi('catch');
	removeApi('class');
	removeApi('const_cast');
	removeApi('delete');
	removeApi('dynamic_cast');
	removeApi('false');
	removeApi('friend');
	removeApi('mutable');
	removeApi('namespace');
	removeApi('new');
	removeApi('operator');
	removeApi('private');
	removeApi('protected');
	removeApi('public');
	removeApi('reinterpret_cast');
	removeApi('static_cast');
	removeApi('template');
	removeApi('throw');
	removeApi('true');
	removeApi('try');
	removeApi('typeid');
	removeApi('typename');
	removeApi('using');
	removeApi('virtual');
	removeApi('this');
	removeApi('export');
	removeApi('explicit');
	//removeApi('');

	$keywords['index'] = "Main";

	ksort($api);

	@mkdir('html', 0777);
	@mkdir('html/i', 0777);
	copy('style.css', 'html/i/style.css');
	copy('arrow.gif', 'html/i/arrow.gif');

	// Creamos el API
	foreach ($api as $name => &$info) {
		$fd = fopen("html/" . $info['file'], 'wb');

			fprintf($fd, "%s\n", '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">');
			fprintf($fd, "%s\n\n", '<html><head><title>' . htmlentities($name) . '</title><link href="i/style.css" rel="stylesheet" type="text/css"></head><body>');

			// Navigation
			fprintf($fd, "%s\n", '<!-- Navigation !-->');
			fprintf($fd, "%s\n", '<ul id="navigation">');
			fprintf($fd, "\t%s\n", '<li><a href="index.html">Main</a></li>');
			if ($info['mustList']) fprintf($fd, "\t%s\n", '<li><a href="api.html">Function Reference</a></li>');
			fprintf($fd, "\t%s\n", '<li><a href="' . $info['catid'] . '.html">' . $info['cat'] . '</a></li>');
			fprintf($fd, "\t%s\n", '<li><a href="' . $info['file'] . '" class="active">' . $name . '</a></li>');
			fprintf($fd, "%s\n\n", '</ul>');

			// Top
			fprintf($fd, "%s\n", '<!-- TOP !-->');
			fprintf($fd, "%s\n", '<a name="top"></a><h1 id="function_name">' . $name . '</h1>');
			fprintf($fd, "%s\n\n", '<p id="function_shortdesc">' . $info['shortdesc'] . '</p>');

			// Use
			fprintf($fd, "%s\n", '<!-- Use !-->');
			fprintf($fd, "%s\n", '<h2>Use:</h2>');
			fprintf($fd, "%s", '<pre>');
			$n = 0;
			foreach (explode("\n", $info['use']) as $line) { $line = trim($line);
				if (!strlen($line)) continue;
				if ($n != 0) fprintf($fd, "\n");
				fprintf($fd, "%s", $line);
				$n++;
			}
			fprintf($fd, "%s\n\n", '</pre>');

			// Description
			fprintf($fd, "%s\n", '<!-- Description !-->');
			fprintf($fd, "%s\n", '<h2>Description:</h2>');
			fprintf($fd, "%s\n\n", '<div id="desc">' . $info['desc'] . '</div>');

			// Related
			fprintf($fd, "%s\n", '<!-- See also !-->');
			fprintf($fd, "%s\n", '<h2>See also:</h2>');
			fprintf($fd, "%s\n", '<ul id="seealso">');
			foreach ($info['related'] as $rel) {
				if (!isset($keywords[$rel])) continue;
				if (isset($api[$rel]['shortdesc'])) {
					fprintf($fd, "\t%s\n", '<li><a href="' . ggn($rel) . '.html">' . $rel . '</a> - ' . htmlentities($api[$rel]['shortdesc']) . '</li>');
				} else {
					fprintf($fd, "\t%s\n", '<li><a href="' . ggn($rel) . '.html">' . $rel . '</a></li>');
				}
			}
			fprintf($fd, "%s\n\n", '</ul>');

			// End
			fprintf($fd, "%s\n", '</body></html>');

		fclose($fd);
	}

	// API
	$fd = fopen('html/api.html', 'wb');

		fprintf($fd, "%s\n", '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">');
		fprintf($fd, "%s\n\n", '<html><head><title>Function Reference</title><link href="i/style.css" rel="stylesheet" type="text/css"></head><body>');

		// Navigation
		fprintf($fd, "%s\n", '<!-- Navigation !-->');
		fprintf($fd, "%s\n", '<ul id="navigation">');
		fprintf($fd, "\t%s\n", '<li><a href="index.html">Main</a></li>');
		fprintf($fd, "\t%s\n", '<li><a href="api.html" class="active">Function Reference</a></li>');
		fprintf($fd, "%s\n\n", '</ul>');

		// Top
		fprintf($fd, "%s\n", '<!-- TOP !-->');
		fprintf($fd, "%s\n", '<a name="top"></a><h1 id="function_name">Function Reference</h1>');
		fprintf($fd, "%s\n\n", '<p id="function_shortdesc">Reference of standard C api</p>');

		fprintf($fd, "%s\n", '<h2 id="by_name">By category:</h2>');
		fprintf($fd, "%s\n", '<ul>');

		foreach ($api_cat as $catid => &$info2) {
			if (!$info2['mustList']) continue;
			fprintf($fd, "%s\n", '<li><a href="' . $catid . '.html">' . htmlentities($info2['title']) . '</a></li>');
		}

		fprintf($fd, "%s\n", '</ul>');

		fprintf($fd, "%s\n", '<h2 id="by_name">By name:</h2>');

		// Table
		fprintf($fd, "%s\n", '<!-- Table !-->');
		fprintf($fd, "%s\n", '<table id="by_name_table">');

		$n = 0;
		foreach ($api as $name => &$info) {
			if ($info['mustList']) {
				fprintf($fd, "\t<tr><td class=\"" . (($n % 2 == 0) ? 'a' : 'b') . "\"><a href=\"%s\">%s</a></td><td>%s</td></tr>\n", $info['file'], $name, $info['shortdesc']);
			} else {
				fprintf($fd, "\t<tr><td class=\"" . (($n % 2 == 0) ? 'a' : 'b') . "\"><strong><a href=\"%s\">%s</a></strong></td><td>%s</td></tr>\n", $info['file'], $name, $info['shortdesc']);
			}
			$n++;
		}

		fprintf($fd, "%s\n", '</table>');

		// End
		fprintf($fd, "%s\n", '</body></html>');

	fclose($fd);

	// API CATS

	foreach ($api_cat as $catid => &$info2) {
		$title = $info2['title'];

		$fd = fopen('html/' . $catid . '.html', 'wb');

			fprintf($fd, "%s\n", '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">');
			fprintf($fd, "%s\n\n", '<html><head><title>' . htmlentities($title) . '</title><link href="i/style.css" rel="stylesheet" type="text/css"></head><body>');

			// Navigation
			fprintf($fd, "%s\n", '<!-- Navigation !-->');
			fprintf($fd, "%s\n", '<ul id="navigation">');
			fprintf($fd, "\t%s\n", '<li><a href="index.html">Main</a></li>');
			if ($info2['mustList']) fprintf($fd, "\t%s\n", '<li><a href="api.html">Function Reference</a></li>');
			fprintf($fd, "\t%s\n", '<li><a href="' . $catid . '.html" class="active">' . $title . '</a></li>');
			fprintf($fd, "%s\n\n", '</ul>');

			// Top
			fprintf($fd, "%s\n", '<!-- TOP !-->');
			fprintf($fd, "%s\n", '<a name="top"></a><h1 id="function_name">' . $title . '</h1>');

			fprintf($fd, "%s\n", '<h2 id="by_name">By name:</h2>');

			// Table
			fprintf($fd, "%s\n", '<!-- Table !-->');
			fprintf($fd, "%s\n", '<table id="by_name_table">');

			ksort($info2['list']);
			$n = 0;
			foreach ($info2['list'] as $name => &$info) {
				fprintf($fd, "\t<tr><td class=\"" . (($n % 2 == 0) ? 'a' : 'b') . "\"><a href=\"%s\">%s</a></td><td>%s</td></tr>\n", $info['file'], $name, $info['shortdesc']);
				$n++;
			}

			fprintf($fd, "%s\n", '</table>');

			// End
			fprintf($fd, "%s\n", '</body></html>');

		fclose($fd);
	}

	// SPECIAL
	foreach ($pages as $catid => &$info) {
		$title = $info['title'];

		$fd = fopen('html/' . $catid . '.html', 'wb');

			fprintf($fd, "%s\n", '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">');
			fprintf($fd, "%s\n\n", '<html><head><title>' . htmlentities($title) . '</title><link href="i/style.css" rel="stylesheet" type="text/css"></head><body>');

			// Navigation
			fprintf($fd, "%s\n", '<!-- Navigation !-->');
			fprintf($fd, "%s\n", '<ul id="navigation">');
			fprintf($fd, "\t%s\n", '<li><a href="index.html">Main</a></li>');
			fprintf($fd, "\t%s\n", '<li><a href="' . $catid . '.html" class="active">' . $title . '</a></li>');
			fprintf($fd, "%s\n\n", '</ul>');

			// Top
			fprintf($fd, "%s\n", '<!-- TOP !-->');
			fprintf($fd, "%s\n", '<a name="top"></a><h1 id="function_name">' . $title . '</h1>');

			fprintf($fd, "%s\n", $info['html']);

			// End
			fprintf($fd, "%s\n", '</body></html>');

		fclose($fd);
	}

	// INDEX
	$fd = fopen('html/index.html', 'wb');

		fprintf($fd, "%s\n", '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">');
		fprintf($fd, "%s\n\n", '<html><head><title>Main - C Reference</title><link href="i/style.css" rel="stylesheet" type="text/css"></head><body>');

		// Navigation
		fprintf($fd, "%s\n", '<!-- Navigation !-->');
		fprintf($fd, "%s\n", '<ul id="navigation">');
		fprintf($fd, "\t%s\n", '<li><a href="index.html" class="active">Main</a></li>');
		fprintf($fd, "%s\n\n", '</ul>');

		// Top
		fprintf($fd, "%s\n", '<!-- TOP !-->');
		fprintf($fd, "%s\n", '<a name="top"></a><h1 id="function_name">C Reference</h1>');

		fprintf($fd, "%s\n", '<ul>');
		fprintf($fd, "%s\n", '<li><a href="-keywords.html">Keywords</a></li>');
		fprintf($fd, "%s\n", '<li><a href="-preprocessor.html">Pre-processor Commands</a></li>');
		fprintf($fd, "%s\n", '<li><a href="-precedence.html">Operator Precedence</a></li>');
		fprintf($fd, "%s\n", '<li><a href="-escape.html">Escape Sequences</a></li>');
		fprintf($fd, "%s\n", '<li><a href="-ascii.html">ASCII Chart</a></li>');
		fprintf($fd, "%s\n", '<li><a href="-types.html">Data Typest</a></li>');
		fprintf($fd, "%s\n", '<li><a href="api.html">Function Reference</a></li>');
		fprintf($fd, "%s\n", '</ul>');

		fprintf($fd, "%s\n", '</table>');

	fclose($fd);

	$fd = fopen('../../packages/base/help.idx', 'wb');
	$keys = array_keys($keywords); sort($keys);
	foreach ($keys as $title) fprintf($fd, "%s@C.chm::/%s.html\n", $title, str_replace('#', '_', $title));
	fclose($fd);

	$files = array();

	$files[] = 'i\\style.css';
	$files[] = 'i\\arrow.gif';

	// Index
	$fd = fopen('html/index.hhk', 'wb');

		fprintf($fd, "%s\n", '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">');
		fprintf($fd, "%s\n", '<HTML><HEAD><!-- Sitemap 1.0 --></HEAD><BODY><UL>');

		foreach ($keywords as $key => $title) {
			$files[] = ($file = ggn($key) . '.html');
			fprintf($fd, "\t%s\n", '<LI><OBJECT type="text/sitemap"><param name="Name" value="' . htmlentities($title) . '"><param name="Local" value="' . htmlentities($file) . '"></OBJECT>');
		}

		fprintf($fd, "%s", '</UL></BODY></HTML>');

	fclose($fd);

	// Project
	$fd = fopen('html/index.hhp', 'wb');

	fprintf($fd, "%s\n", '[OPTIONS]');
	fprintf($fd, "%s\n", 'Compatibility=1.1 or later');
	fprintf($fd, "%s\n", 'Compiled file=..\\..\\..\\packages\\base\\docs\\C.chm');
	fprintf($fd, "%s\n", 'Default topic=index.html');
	fprintf($fd, "%s\n", 'Display compile progress=No');
	fprintf($fd, "%s\n", 'Index file=index.hhk');
	fprintf($fd, "%s\n", 'Language=0xc0a Español (alfabetización internacional)');
	fprintf($fd, "%s\n", 'Title=C Reference');
	fprintf($fd, "%s\n", '');
	fprintf($fd, "%s\n", '[FILES]');
	foreach ($files as $file) {
		fprintf($fd, "%s\n", $file);
	}
	fprintf($fd, "%s\n", '');

	fclose($fd);

	chdir('html');

	system('"C:\\Archivos de programa\\HTML Help Workshop\\hhc.exe" index.hhp');
	chdir('..');
?>