module util.ini;

private import std.file, std.string, std.stream, std.stdio, std.utf;

class SimpleIni {
	private char[][] lines;

	char[][char[]][char[]] sections;

	static private char[] addslashes(char[] s) {
		char[] r;
		for (int n = 0; n < s.length; n++) {
			char c = s[n];
			switch (c) {
				case '\\':  r ~= "\\\\"; continue;
				case '\n':  r ~= "\\n"; continue;
				case '\r':  r ~= "\\r"; continue;
				case '\t':  r ~= "\\t"; continue;
				default:
			}
			r ~= c;
		}
		return r;
	}

	static private char[] stripslashes(char[] s) {
		char[] r;
		for (int n = 0; n < s.length; n++) {
			char c = s[n];
			if (c == '\\') {
				if (++n >= s.length) break;
				c = s[n];
				switch (c) {
					case 'n': c = '\n'; break;
					case 'r': c = '\r'; break;
					case 't': c = '\t'; break;
					default: break;
				}
			}

			r ~= c;
		}
		return r;
	}

	void saveStream(Stream s) {
		foreach (key; sections.keys) {
			s.writeLine(format("[%s]", key));
			foreach (nkey; sections[key].keys) {
				char[] value = sections[key][nkey];
				s.writeLine(format("%s = \"%s\"", nkey, addslashes(value)));
			}
			s.writeLine("");
		}
	}

	void[] saveString() {
		MemoryStream s = new MemoryStream();
		saveStream(s);
		return s.data;
	}

	void saveFile(char[] file) {
		File s = new File(file, FileMode.OutNew);
		saveStream(s);
		s.close();
	}

	void parse(bool clean = true) {
		char[] section = "";

		if (clean) {
			foreach (key; sections.keys) sections.remove(key);
		}

		foreach (line; lines) {
			line = strip(line);

			if (!line.length) continue;

			if (line[0] == ';' || line[0] == '#') continue;

			if (line[0] == '[') {
				section = tolower(strip(line[1..line.length - 1]));
				continue;
			}

			int pos = void;
			if ((pos = find(line, "=")) == -1) continue;

			char[] name   = tolower(strip(line[0..pos]));
			char[] value  = strip(line[pos + 1..line.length]);

			if (value.length > 0) {
				if (value[0] == '"') value = value[1..value.length];
				if (value[value.length - 1] == '"') value = value[0..value.length - 1];
			}

			set(section, name, std.utf.toUTF8(stripslashes(value)));
			//set(section, name, stripslashes(value));
		}
	}

	char[] set(char[] section, char[] name, char[] value) {
		return (sections[section][name] = value);
	}

	char[] set(char[] section, char[] name, bool value) {
		return (sections[section][name] = std.string.format("%d", value));
	}

	char[] set(char[] section, char[] name, int value) {
		return (sections[section][name] = std.string.format("%d", value));
	}

	char[] get(char[] section, char[] name) {
		name    = tolower(strip(name));
		section = tolower(strip(section));

		if ((section in sections)          is null) return "";
		if ((name    in sections[section]) is null) return "";

		return sections[section][name];
	}

	int getInteger(char[] section, char[] name, int dvalue = 0) {
		try { return std.conv.toInt(get(section, name)); } catch (Exception e) { return dvalue; }
	}

	bool getBoolean(char[] section, char[] name, bool dvalue = false) {
		try { return std.conv.toInt(get(section, name)) != 0; } catch (Exception e) { writefln("error (%s): %s", get(section, name), e.toString()); return dvalue; }
	}

	char[] get_default(char[] section, char[] name, char[] value) {
		char[] r = get(section, name);
		if (r.length == 0) return value;
		return r;
	}

	bool loadStream(Stream stream, bool utf = false) {
		lines.length = 0;
		while (!stream.eof) lines ~= std.utf.toUTF8(stream.readLine);
		parse();
		return true;
	}

	bool loadFile(char[] file, bool utf = false) {
		if (!exists(file)) return false;
		char[] data = std.utf.toUTF8(cast(char[])std.file.read(file));
		lines = split(data, "\n");
		parse();
		return true;
	}

	void loadString(void[] data, bool utf = false) {
		MemoryStream s = new MemoryStream(cast(ubyte[])data);
		loadStream(s, utf);
	}

	this(char[] file, bool utf = false) {
		if (!loadFile(file, utf)) throw(new Exception("File '" ~ file ~ "' doesn't exists"));
	}

	this(Stream stream, bool utf = false) {
		loadStream(stream, utf);
	}

	this() {
	}
}