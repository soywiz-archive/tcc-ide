module main;

private import std.stdio, std.ctype, std.string, std.process, std.file, std.c.windows.windows;
private import std.c.stdio, std.c.stdlib, std.path, std.zip;
private import std.stream, std.conv, std.gc, std.thread;

private import dfl.scintillaext, dfl.splitterext, dfl.closeabletabcontrol;
private import dfl.all;
private import dfl.internal.winapi, dfl.internal.wincom;

private import gotoform, inputform, findreplaceform, misc, htmlhelp;
private import util.ini;

char[] rootPath;

void associateExtension(char[] ext, char[] type, char[] exe) {
	RegistryKey root = Registry.classesRoot();
	root.createSubKey("." ~ ext).setValue("", type);
	root.createSubKey(type ~ "\\shell\\open\\command").setValue("", exe ~ " \"%1\"");
	root.createSubKey(type ~ "\\DefaultIcon").setValue("",  exe ~ ",1");
}

void associateExtensions() {
	char[] exe = Application.executablePath;
	associateExtension("tccproj", "TccIde.Project", exe);
	associateExtension("tccpack", "TccIde.Package", exe);
}

void[] read(Stream stream) {
	ubyte[] data;
	while (!stream.eof) {
		ubyte[] temp; temp.length = stream.available;
		temp.length = stream.read(temp); data ~= temp;
	}
	return data;
}

class ZipArchiveStream : public ZipArchive {
	this(Stream stream) { super(read(stream)); }
	this(void[] data) { super(data); }
	this() { super(); }
	void build(Stream stream) { stream.copyFrom(new MemoryStream(cast(ubyte[])super.build())); }
	void[] build() { return super.build; }
}

// Clase encargada de almacenar un proyecto
class Project {
	char[] name;
	char[] path;
	char[][char[]] metainfo;
	char[][] dependencies = ["base", "win32", "gamelib"];
	bool opened;
	bool saved;
	SourceList sourceList;
	SimpleIni options;

	this(char[] path) {
		this.path = path;
		this();
	}

	this() {
		this.name = "untitled";
		options = new SimpleIni();
	}

	void reset() {
		options.set("common", "wait", true);
	}

	void updateName() {
		name = getName(getBaseName(path));
	}

	bool save(bool ask = false) {
		writefln("project: {");
		writefln("  name: %s", name);
		writefln("  path: %s", path);
		writefln("}");
		if (ask || !this.path.length) {
			SaveFileDialog sfd = new SaveFileDialog;
			sfd.filter = "Archivos de proyecto (*.tccproj)|*.tccproj|Todos los archivos (*.*)|*.*";
			//sfd.initialDirectory = getDirName(getDirName(Application.executablePath)) ~ "\\projects";
			sfd.initialDirectory = getDirName(path);
			sfd.defaultExt = "tccproj";
			sfd.fileName = "untitled.tccproj";
			if (DialogResult.OK != sfd.showDialog()) return false;
			this.path = sfd.fileName;
			if (getExt(this.path) == null) this.path ~= ".tccproj";
		}

		char[][] openedFiles = [];
		foreach (item; sourceList.items) {
			Source source = cast(Source)item;
			if (!source.opened) continue;
			openedFiles ~= (source.focused ? "*" : "") ~ source.name;
		}

		ZipArchiveStream zas = new ZipArchiveStream();

		this.metainfo[".dependencies"] = std.string.join(dependencies, "\n");
		this.metainfo[".opened"] = std.string.join(openedFiles, "\n");
		this.metainfo[".options"] = cast(char[])options.saveString();

		foreach (name, data; metainfo) {
			ArchiveMember am = new ArchiveMember;
			am.expandedData = cast(ubyte[])data;
			am.name = name;
			am.compressionMethod = 8;
			zas.addMember(am);
		}

		foreach (item; sourceList.items) {
			Source source = cast(Source)item;
			ArchiveMember am = new ArchiveMember;
			am.expandedData = cast(ubyte[])source.data;
			am.name = source.name;
			am.compressionMethod = 8;
			zas.addMember(am);
		}

		//zas.build(new File(path, FileMode.OutNew));
		write(path, cast(void[])zas.build);

		delete zas;

		this.saved = true;

		updateName();

		return true;
	}

	bool opening(bool ask = true) {
		if (ask || !this.path.length) {
			OpenFileDialog sfd = new OpenFileDialog;
			sfd.filter = "Archivos de proyecto (*.tccproj)|*.tccproj|Todos los archivos (*.*)|*.*";
			//sfd.initialDirectory = getDirName(getDirName(Application.executablePath)) ~ "\\projects";
			sfd.defaultExt = "tccproj";
			if (DialogResult.OK != sfd.showDialog()) return false;
			this.path = sfd.fileName;
		}
		return true;
	}

	bool open(bool ask = true) {
		if (ask || !this.path.length) {
			OpenFileDialog sfd = new OpenFileDialog;
			sfd.filter = "Archivos de proyecto (*.tccproj)|*.tccproj|Todos los archivos (*.*)|*.*";
			//sfd.initialDirectory = getDirName(getDirName(Application.executablePath)) ~ "\\projects";
			sfd.defaultExt = "tccproj";
			if (DialogResult.OK != sfd.showDialog()) return false;
			this.path = sfd.fileName;
		}

		ZipArchiveStream zas = new ZipArchiveStream(std.file.read(this.path));
		foreach (e; zas.directory) zas.expand(e);

		try { dependencies = std.string.split(cast(char[])zas.directory[".dependencies"].expandedData, "\n"); } catch (Exception e) { }
		char[][] openedFilesD; try { openedFilesD = std.string.split(cast(char[])zas.directory[".opened"].expandedData, "\n"); } catch (Exception e) { }

		reset();

		try { options.loadString(zas.directory[".options"].expandedData); } catch (Exception e) { }

		bool[char[]] openedFiles;

		char[] focused;

		foreach (name; openedFilesD) {
			if (name.length > 0 && name[0] == '*') {
				name = name[1..name.length];
				focused = name;
			}
			openedFiles[name] = true;
		}

		sourceList.clear();

		Source focusedSource;

		foreach (e; zas.directory) {
			if (e.name == ".dependencies") continue;
			if (e.name == ".opened") continue;
			if (e.name == ".options") continue;
			Source source = new Source(this);
			source.name = e.name;
			source.title = e.name;
			source.data = cast(char[])e.expandedData;
			source.saved = true;

			if (source.name in openedFiles) {
				source.open();
				if (focused == source.name) focusedSource = source;
			}

			sourceList.add(source);
		}

		if (focusedSource) focusedSource.open();

		delete zas;

		this.opened = true;
		this.saved = true;

		updateName();

		writefln("wait:'%s'", options.get("common", "wait"));

		return true;
	}
}

class Source {
	protected static int uniqueid;
	int id;

	Project project;
	ScintillaExtended editor;

	char[] title;
	char[] name;

	bool _saved;

	bool saved() {
		return _saved;
	}

	bool saved(bool savedNew) {
		if (!savedNew) project.saved = false;
		return this._saved = savedNew;
	}

	protected char[] _data;

	bool opened() {
		return editor !is null;
	}

	bool focused() {
		if (!opened) return false;
		return (that.tc.selectedTab is cast(TabPage)editor.parent);
	}

	this(Project project) {
		id = ++uniqueid;
		this.project = project;
	}

	void open(ScintillaExtended editor) {
		this.editor = editor;
		this.editor.text = data;
	}

	void open() {
		TabControl tc = that.tc;

		// Si está abierto, lo enfocamos
		if (opened) {
			//MainForm
			int idx = tc.tabPages.indexOf(cast(TabPage)editor.parent);
			tc.selectedIndex = idx;
			tc.selectedIndexChanged(tc, EventArgs.empty);
		}
		// Si está cerrado, lo abrimos
		else {
			//that.addFileTab();
			that.addFileTab(this);
		}
	}

	void close() {
		if (!opened) {
			editor = null;
			return;
		}
		saved = editor.saved;
		/*if (opened) {
			TabControl tc = that.tc;
			tc.tabPages.remove(cast(TabPage)editor.parent);
		}*/
		//project.sourceList.remove(this);
		this._data = editor.text;
		editor = null;
	}

	char[] data() {
		if (editor) return editor.text;
		return _data;
	}

	char[] data(char[] text) {
		if (editor) { editor.text = text; return text; }
		return _data = text;
	}

	int opCmp(Object b) {
		return icmp(this.name, (cast(Source)b).name);
	}
}

class SourceList : ListBox {
	this() {
		itemHeight = 18;
		font = new Font("Arial", cast(float)9, FontStyle.REGULAR);
		drawMode = DrawMode.OWNER_DRAW_FIXED;
	}

	override private void onKeyPress(KeyPressEventArgs kea) {
		writefln("lol");
		//addShortcut(Keys.F2, delegate void(Object sender, FormShortcutEventArgs ea) {  });
		that.showHelp();
		super.onKeyPress(kea);
	}

	void update(Source source) {
	}

	void add(Source source) {
		items.add(source);
		sort();
	}

	void remove(Source source) {
		source.close();
		items.remove(source);
		sort();
	}

	void clear() {
		while (items.length) remove(cast(Source)items[0]);
		//sort();
	}

	void onDrawItem(DrawItemEventArgs ea) {
		Source item = cast(Source)items[ea.index];
		ea.drawBackground();
		//ea.graphics.drawIcon(that.icon, ea.bounds.x + 2, ea.bounds.y + 2);
		ea.graphics.drawIcon(that.icon, Rect(ea.bounds.x + 8, ea.bounds.y + 1, 16, 16));
		ea.graphics.drawText(item.name, ea.font, ea.foreColor, Rect(ea.bounds.x + 30, ea.bounds.y + 1, ea.bounds.width - 36, 13));
		ea.drawFocusRectangle();
	}

	override protected void onDoubleClick(EventArgs ea) {
		(cast(Source)items[selectedIndex]).open();
	}

	void menuOpen(Object mi, EventArgs ea) {
		onDoubleClick(ea.empty);
	}

	void menuRename(Object mi, EventArgs ea) {
		//(cast(Source)items[selectedIndex]).rename();
	}

	void menuRemove(Object mi, EventArgs ea) {
		if (msgBox(that, "¿Está seguro de querer quitar el fichero del proyecto?\n(No podrá recuperarlo)", "Tiny C IDE", MsgBoxButtons.YES_NO, MsgBoxIcon.ASTERISK, MsgBoxDefaultButton.BUTTON2) == DialogResult.NO) return;
		TabControl tc = that.tc;
		Source source = cast(Source)items[selectedIndex];
		if (source.opened && source.editor) {
			that.closeTab(cast(TabPage)source.editor.parent);
			//tc.tabPages.remove();
		}
		source.close();
		remove(source);
	}

	override protected void onMouseDown(MouseEventArgs mea) {
		scope (exit) super.onMouseDown(mea);

		if (mea.button != MouseButtons.RIGHT) return;

		int index = indexFromPoint(mea.x, mea.y);
		if (index != selectedIndex) selectedIndex = index;

		if (index >= 0) {
			ContextMenu menu = new ContextMenu;
			menu.menuItems.add(NewMenuItem("&Editar", &menuOpen));
			menu.menuItems.add("-");
			menu.menuItems.add(NewMenuItem("&Renombrar", &menuRename));
			menu.menuItems.add(NewMenuItem("&Quitar", &menuRemove));
			//writefln(menu.mousePosition

			menu.show(this, Point(mousePosition.x, mousePosition.y));
		}
	}
}

MenuItem NewMenuItem(char[] name, void delegate(Object sender, EventArgs ea) callback = null, MenuItem[] list = null) {
	MenuItem mi = new MenuItem(name, list);
	if (callback) mi.click ~= callback;
	return mi;
}

static MainForm that;

class MainForm : dfl.form.Form {
	SourceList sourceList;
	ScintillaExtended _currentSource;

	ScintillaExtended currentSource(ScintillaExtended source) {
		_currentSource = source;

		bool canEdit = (currentSource !is null);

		foreach (cmi; editMI) cmi.enabled = canEdit;

		return _currentSource;
	}

	ScintillaExtended currentSource() {
		return _currentSource;
	}

	MenuItem[char[]] MI;
	MenuItem[] editMI;

	StatusBar sbar;
	ScintillaExtended downSci;
	TabPage tp;
	CloseableTabControl tc;
	SplitterExt split;
	ContainerControl cc;
	char[][][char[]] idxList;
	int nextFile = 1;
	Project project;

	CheckBox waitCheckBox;

	char[] status(char[] stat) { sbar.text = stat; return stat; }
	char[] status() { return sbar.text; }

	bool checkSelectedSource() {
		if (currentSource) return true;
		msgBox("Se requiere una pestaña de código abierta");
		return false;
	}

	this() {
		HtmlHelp.Register();

		icon = new Icon(LoadIconA(GetModuleHandleA(null), cast(char*)101));
		project = new Project;

		that = this;

		width = 640;
		height = 480;

		startPosition = FormStartPosition.CENTER_SCREEN;
		windowState = dfl.form.FormWindowState.MAXIMIZED;
		text = "Tiny C IDE (Untitled-1)";
		formBorderStyle = dfl.form.FormBorderStyle.SIZABLE;

		// Shortcuts
		addShortcut(Keys.F1, delegate void(Object sender, FormShortcutEventArgs ea) { that.showHelp(); });
		addShortcut(Keys.F2, delegate void(Object sender, FormShortcutEventArgs ea) { that.renameTab(); });
		addShortcut(Keys.F3, delegate void(Object sender, FormShortcutEventArgs ea) { that.showFindNext(); });
		addShortcut(Keys.F5, delegate void(Object sender, FormShortcutEventArgs ea) { that.execute(); });
		addShortcut(Keys.CONTROL | Keys.N, delegate void(Object sender, FormShortcutEventArgs ea) { that.newFile(); });
		addShortcut(Keys.CONTROL | Keys.S, delegate void(Object sender, FormShortcutEventArgs ea) { that.saveProject(); });
		addShortcut(Keys.CONTROL | Keys.O, delegate void(Object sender, FormShortcutEventArgs ea) { that.openProject(); });
		addShortcut(Keys.CONTROL | Keys.P, delegate void(Object sender, FormShortcutEventArgs ea) { that.managePackages(); });

		addShortcut(Keys.CONTROL | Keys.F4, delegate void(Object sender, FormShortcutEventArgs ea) { that.removeTab(); });
		addShortcut(Keys.CONTROL | Keys.F, delegate void(Object sender, FormShortcutEventArgs ea) { that.showFindReplace(); } );
		addShortcut(Keys.CONTROL | Keys.R, delegate void(Object sender, FormShortcutEventArgs ea) { that.showFindReplace_replace(); } );
		addShortcut(Keys.CONTROL | Keys.G, delegate void(Object sender, FormShortcutEventArgs ea) { that.showGotoLine(); } );
		addShortcut(Keys.CONTROL | Keys.TAB, &shortcut_ControlTab);
		addShortcut(Keys.CONTROL | Keys.SHIFT | Keys.TAB, &shortcut_ControlShiftTab);

		closing ~= delegate void(Object sender, CancelEventArgs cea) { cea.cancel = !that.closeProject(); };

		menu = new MainMenu();

		with (menu) {
			menuItems.add(
				NewMenuItem("&Archivo", null, [
					NewMenuItem("Nuevo &proyecto", delegate void(Object sender, EventArgs ea) { that.newProject(); }),
					NewMenuItem("&Abrir proyecto...\tCtrl+O", delegate void(Object sender, EventArgs ea) { that.openProject(); }),
					NewMenuItem("&Guardar proyecto\tCtrl+S", delegate void(Object sender, EventArgs ea) { that.saveProject(); }),
					NewMenuItem("-"),
					NewMenuItem("Nuevo &fuente\tCtrl+N", delegate void(Object sender, EventArgs ea) { that.newFile(); }),
					NewMenuItem("&Cerrar fuente\tCtrl+F4", delegate void(Object sender, EventArgs ea) { that.removeTab(); }),
					NewMenuItem("&Renombrar Fuente\tF2", delegate void(Object sender, EventArgs ea) { that.renameTab(); }),
					NewMenuItem("-"),
					NewMenuItem("&Salir\tAlt+F4", delegate void(Object sender, EventArgs ea) { that.close(); })
				])
			);

			menuItems.add(
				NewMenuItem("&Editar", null, [
					MI["undo"] = NewMenuItem("Deshacer\tCtrl+Z", delegate void(Object sender, EventArgs ea) { if (!that.checkSelectedSource) return; that.currentSource.sendEditor(SCI_UNDO); }),
					MI["redo"] = NewMenuItem("Rehacer\tCtrl+Y", delegate void(Object sender, EventArgs ea) { if (!that.checkSelectedSource) return; that.currentSource.sendEditor(SCI_REDO); }),
					NewMenuItem("-"),
					MI["cut"] = NewMenuItem("Cortar\tCtrl+X", delegate void(Object sender, EventArgs ea) { if (!that.checkSelectedSource) return; that.currentSource.sendEditor(SCI_CUT); }),
					MI["copy"] = NewMenuItem("Copiar\tCtrl+C", delegate void(Object sender, EventArgs ea) { if (!that.checkSelectedSource) return; that.currentSource.sendEditor(SCI_COPY); }),
					MI["paste"] = NewMenuItem("Pegar\tCtrl+V", delegate void(Object sender, EventArgs ea) { if (!that.checkSelectedSource) return; that.currentSource.sendEditor(SCI_PASTE); }),
					MI["del"] = NewMenuItem("Borrar\tDel", delegate void(Object sender, EventArgs ea) { if (!that.checkSelectedSource) return; that.currentSource.sendEditor(SCI_CLEAR); }),
					NewMenuItem("-"),
					MI["selectall"] = NewMenuItem("Seleccionar todo\tCtrl+A", delegate void(Object sender, EventArgs ea) { if (!that.checkSelectedSource) return; that.currentSource.sendEditor(SCI_SELECTALL); })
				])
			);

			menuItems.add(
				NewMenuItem("&Buscar", null, [
					MI["find"] = NewMenuItem("Buscar y reemplazar...\tCtrl+F", delegate void(Object sender, EventArgs ea) { that.showFindReplace(); }),
					MI["find_next"] = NewMenuItem("Buscar siguiente...\tF3", delegate void(Object sender, EventArgs ea) { that.showFindNext(); }),
					NewMenuItem("-"),
					MI["goto"] = NewMenuItem("Ir a línea...\tCtrl+G", delegate void(Object sender, EventArgs ea) { that.showGotoLine(); })
				])
			);

			menuItems.add(
				NewMenuItem("&Ejecutar", null, [
					NewMenuItem("Ejecutar...\tF5", delegate void(Object sender, EventArgs ea) { that.execute(); }),
					NewMenuItem("-"),
					NewMenuItem("Guardar Ejecutable...", delegate void(Object sender, EventArgs ea) { that.execute(true); })
				])
			);

			menuItems.add(
				NewMenuItem("&Paquetes", null, [
					NewMenuItem("Administrar paquetes...", delegate void(Object sender, EventArgs ea) { that.managePackages(); })
				])
			);

			menuItems.add(
				NewMenuItem("A&yuda", null, [
					NewMenuItem("&Ayuda contextual...\tF1", delegate void(Object sender, EventArgs ea) { that.showHelp(); }),
					NewMenuItem("-"),
					MI["guides"] = NewMenuItem("&Manuales"),
					NewMenuItem("-"),
					NewMenuItem("Sobre...", delegate void(Object sender, EventArgs ea) { msgBox("Tiny C IDE 0.1\n\nPor Carlos Ballesteros Velasco"); })
				])
			);

			editMI ~= MI["undo"];
			editMI ~= MI["redo"];
			editMI ~= MI["cut"];
			editMI ~= MI["copy"];
			editMI ~= MI["paste"];
			editMI ~= MI["del"];
			editMI ~= MI["selectall"];
			editMI ~= MI["find"];
			editMI ~= MI["goto"];
		}

		with (sbar = new StatusBar()) {
			dock = dfl.control.DockStyle.BOTTOM;
			bounds = Rect(0, 250, 292, 23);
			parent = this;
			width = 120;
		}

		TabPage rtp;

		with (cc = new UserControl()) {
			with (new TabControl) {
				dock = DockStyle.BOTTOM;
				rtp = new TabPage("Dependencias");
				with (new ListBox) {
					dock = DockStyle.FILL;
					//borderStyle = dfl.base.BorderStyle.NONE;
					parent = rtp;
					height = 300;
				}
				parent = cc;
				tabPages.add(rtp);
			}

			with (split = new SplitterExt()) {
				minSize = 0;
				dock = DockStyle.BOTTOM;
				parent = cc;
				//width = 5;
			}

			with (new TabControl) {
				dock = DockStyle.FILL;
				rtp = new TabPage("Ficheros");
				with (sourceList = new SourceList) {
					dock = DockStyle.FILL;
					//borderStyle = dfl.base.BorderStyle.NONE;
					parent = rtp;
				}
				parent = cc;
				tabPages.add(rtp);
			}

			width = 180;
			dock = dfl.control.DockStyle.LEFT;
			parent = this;
		}

		with (split = new SplitterExt()) {
			minSize = 0;
			dock = DockStyle.LEFT;

			defaultPos = 180;

			parent = this;
		}

		with (new TabControl) {
			dock = DockStyle.BOTTOM;
			tp = new TabPage("Compilación");
			with (downSci = new ScintillaExtended()) {
				borderStyle = dfl.base.BorderStyle.NONE;
				height = 140;
				handleCreated ~= &sci_handleCreated;
				parent = tp;
			}
			tabPages.add(tp);
			tp = new TabPage("Opciones de proyecto");
			with (waitCheckBox = new CheckBox) {
				left = 10;
				top = 10;
				text = "Mantener abierta la ventana al terminar la ejecucicón (consola)";
				width = 500;
				parent = tp;
				click ~= delegate void(Object sender, EventArgs ea) {
					that.project.options.set("common", "wait", that.waitCheckBox.checked);
				};
			}
			tabPages.add(tp);
			parent = this;
		}

		with (downSci) {
			sendEditor(SCI_SETSEL, 0, 0);
			readOnly = true;

			sendEditor(SCI_SETMARGINTYPEN, 1, 0);
			sendEditor(SCI_SETMARGINWIDTHN, 1, 0);

			sendEditor(SCI_SETMARGINLEFT, 0, 0);
			sendEditor(SCI_SETSCROLLWIDTH, 0);
			dock = DockStyle.FILL;
		}

		with (split = new SplitterExt()) {
			minSize = 0;
			dock = DockStyle.BOTTOM;
			//height = 5;

			parent = this;
		}

		with (tc = new CloseableTabControl) {
			multiline = false;
			dock = DockStyle.FILL;
			//borderStyle = dfl.base.BorderStyle.FIXED_SINGLE;
			parent = this;
			selectedIndexChanged ~= &tabChanged;

			beforeCloseTab ~= delegate void(CloseableTabControl c, CloseableTabEventArgs ctea) {
				//ctea.allow = (msgBox("¿Desea cerrar el tab '" ~ ctea.tabPage.text ~ "'?", "Alerta", MsgBoxButtons.OK_CANCEL, MsgBoxIcon.ASTERISK) == DialogResult.OK);
				//if (c.tabCount <= 1) ctea.allow = false;
				that.removingTab(ctea.tabPage);
			};

			afterCloseTab ~= delegate void(CloseableTabControl ctc, CloseableTabEventArgs ctea) {
				//ctc.selectedTab.focus();
				//msgBox("Tab cerrado satisfactoriamente");
			};
		}

		project.sourceList = sourceList;

		MI["guides"].menuItems.clear();
		processIdx("base");
		processIdx("win32");
		processIdx("sdl");

		if (openProjectName.length) {
			project.path = openProjectName;
			openProject(false);
		} else {
			newProject();
		}

		status = "Tiny C IDE Inicializado";
	}

	~this() {
		HtmlHelp.Unregister();
	}

	void renameTab() {
		try {
			Source source = (cast(Source)currentSource.tag);
			if (!source) return;
			InputForm ifm = new InputForm();
			ifm.text = "Elija un nombre para el fichero";
			ifm.vtext = source.name;
			ifm.showDialog(this);
			if (ifm.accepted) {
				source.name = ifm.vtext;
				if (source.editor && source.editor.parent) source.editor.parent.text = source.name;
				sourceList.refresh();
			}
		} catch (Exception e) {
			writefln("Shortcut.Keys.F2.Exception(%s)", e.toString);
		}
	}

	void closeTab(TabPage page) {
		tc.selectedTab = page;
		removeTab();
	}

	void removeTab() {
		if (tc.tabCount <= 0) return;
		int sidx = tc.selectedIndex;
		tc.selectedIndex = (tc.selectedIndex == 0) ? (tc.tabCount - 1) : (tc.selectedIndex - 1);

		removingTab(tc.tabPages[sidx]);

		tc.tabPages.removeAt(sidx);
		std.gc.fullCollect();
		tabChanged(null, EventArgs.empty);
	}

	void removingTab(TabPage page) {
		ScintillaExtended sci = cast(ScintillaExtended)page.tag;
		Source source = cast(Source)sci.tag;
		source.close();
		delete sci;
	}

	void removeAllTabs() {
		Object[] list; tc.selectedIndex = 0;
		for (int n = 0; n < tc.tabCount; n++) list ~= tc.tabPages[n].tag; tc.tabPages.clear();
		foreach (Object e; list) { try { delete e; } catch (Exception e) { } }
		std.gc.fullCollect();
	}

	void managePackages() {
		msgBox("Administrar paquetes");
	}

	bool closeProject() {
		bool result = true;
		if (!project.opened) return true;

		if (!project.saved) {
			switch (msgBox(this, "¿Desea guardar el proyecto actual antes de cerrarlo?", "Tiny C IDE", MsgBoxButtons.YES_NO_CANCEL, MsgBoxIcon.ASTERISK, MsgBoxDefaultButton.BUTTON1)) {
				default:
				case DialogResult.YES:
					result = saveProject();
				break;
				case DialogResult.NO:
					result = true;
				break;
				case DialogResult.CANCEL:
					result = false;
				break;
			}
		}

		if (result) {
			sourceList.clear();
			removeAllTabs();
		}

		return result;
	}

	void title(char[] title, bool saved = true) {
		text = std.string.format("Tiny C IDE (%s%s)", title, saved ? "" : " *");
	}

	void updateProjectOptions() {
		waitCheckBox.checked = that.project.options.getBoolean("common", "wait", true);
	}

	bool openProject(bool ask = true) {
		if (project.opening(ask)) {
			if (!closeProject) return false;
			project.open(false);
			status = "Proyecto abierto satisfactoriamente";
			title = project.name;
			updateProjectOptions();
			return true;
		} else {
			status = "No se abrió el proyecto";
			return false;
		}
	}

	bool saveProject() {
		if (project.save()) {
			status = "Proyecto guardado satisfactoriamente";
			return true;
		} else {
			status = "No se guardó el proyecto";
			return false;
		}
	}

	void newFile() {
		that.addFileTab("");
	}

	void newProject() {
		if (!closeProject()) return;

		nextFile = 1;
		removeAllTabs();

		addFileTab(
			"#include <stdio.h>\n"
			"\n"
			"int main(int argc, char argv[][]) {\n"
			"\tprintf(\"Hola mundo!\\n\");\n"
			"\treturn 0;\n"
			"}\n",
		"main.c");

		project.opened = true;
		project.saved = true;
		project.path = "";

		updateProjectOptions();
	}

	TabPage addFileTab(Source source, bool focused = true) {
		if (tc.tabCount >= 50) return null;

		with (tp = new TabPage(source.title)) {
			borderStyle = dfl.base.BorderStyle.NONE;

			with (currentSource = new ScintillaExtended) {
				borderStyle = dfl.base.BorderStyle.NONE;
				text = source.data;
				handleCreated ~= &sci_handleCreated;
				dock = DockStyle.FILL;
				parent = tp;
			}

			tag = currentSource;
		}

		tc.tabPages.add(tp);

		tc.selectedTab = tp;

		currentSource.sendEditor(SCI_SETKEYWORDS, 3, std.string.join(idxList.keys, " "));

		currentSource.focus();

		currentSource.tag = source;

		source.open(currentSource);

		return tp;
	}

	TabPage addFileTab(char[] addText = "", char[] filename = null, bool focused = true) {
		if (tc.tabCount >= 50) return null;

		Source source = new Source(project);
		if (filename is null) {
			source.title = source.name = std.string.format("untitled-%d.c", nextFile);
		} else {
			source.title = source.name = filename;
		}
		nextFile++;

		with (tp = new TabPage(source.title)) {
			borderStyle = dfl.base.BorderStyle.NONE;

			with (currentSource = new ScintillaExtended) {
				borderStyle = dfl.base.BorderStyle.NONE;
				text = addText;
				handleCreated ~= &sci_handleCreated;
				dock = DockStyle.FILL;
				parent = tp;
			}

			tag = currentSource;
		}

		tc.tabPages.add(tp);

		tc.selectedTab = tp;

		currentSource.sendEditor(SCI_SETKEYWORDS, 3,
			std.string.join(idxList.keys, " ")
		);

		currentSource.focus();

		currentSource.tag = source;

		sourceList.add(source);

		source.open(currentSource);

		return tp;
	}

	private void tabChanged(Object sender, EventArgs ea) {
		if (tc.tabCount == 0) {
			currentSource = null;
			return;
		}
		currentSource = cast(ScintillaExtended)tc.tabPages[tc.selectedIndex].tag;
		currentSource.focus();
	}
	
	char[] last_find, last_replace;
	bool last_find_matchCase;
	bool last_find_regExp;
	
	void set_jump_caret() {
		//this.currentSource.sendEditor(SCI_SETXCARETPOLICY, CARET_JUMPS, "3UZ");
		//this.currentSource.sendEditor(SCI_SETYCARETPOLICY, CARET_JUMPS, "3UZ");	
		//this.currentSource.sendEditor(SCI_SETXCARETPOLICY, CARET_JUMPS, 3);
		
		this.currentSource.sendEditor(SCI_SETYCARETPOLICY, CARET_SLOP  , 1);	
		this.currentSource.sendEditor(SCI_SETYCARETPOLICY, CARET_STRICT, 1);	
		this.currentSource.sendEditor(SCI_SETYCARETPOLICY, CARET_JUMPS , 1);	
		this.currentSource.sendEditor(SCI_SETYCARETPOLICY, CARET_EVEN  , 0);	
	}
	
	void showFindNext() {
		TextToFind ttf;
		int sflags = 0;
		bool retry = true;
		
		if (last_find.length == 0) return;
		
		try {

			retryl:
			
			if (last_find_matchCase) sflags |= SCFIND_MATCHCASE;
			if (last_find_regExp   ) sflags |= SCFIND_REGEXP;

			ttf.lpstrText = toStringz(last_find);
			ttf.chrg.cpMin = this.currentSource.sendEditor(SCI_GETCURRENTPOS);
			ttf.chrg.cpMax = this.currentSource.sendEditor(SCI_GETLENGTH);

			this.currentSource.sendEditor(SCI_FINDTEXT, sflags, cast(int)&ttf);

			this.currentSource.sendEditor(SCI_SETSELECTIONSTART, ttf.chrgText.cpMin);
			this.currentSource.sendEditor(SCI_SETSELECTIONEND, ttf.chrgText.cpMax);
			
			if (ttf.chrgText.cpMin == ttf.chrgText.cpMax) {
				if (retry) {
					retry = false;
					goto retryl;
				} else {
					msgBox("No se encontró ninguna coincidencia");
					return;
				}
			}
			
			set_jump_caret();
			this.currentSource.sendEditor(SCI_SCROLLCARET);
		} catch (Exception e) {
			msgBox(e.toString);
		}
		
		//SCI_LINESCROLL(int column, int line)
		
		currentSource.focus();
	}
	
	void onFindProcess(FindReplaceForm frf, FindReplaceEventArgs frea) {
		try {
			last_find = frea.find;
			last_replace = frea.replace;
			last_find_matchCase = frf.matchCase;
			last_find_regExp = frf.regExp;
			frf.close();
			
			showFindNext();
		} catch (Exception e) {
			msgBox(e.toString);
		}
	}
	
	void onReplaceProcess(FindReplaceForm frf, FindReplaceEventArgs frea) {
		last_find = frea.find;
		last_replace = frea.replace;
	
		TextToFind ttf;
		int sflags = 0;
		
		if (frf.matchCase) sflags |= SCFIND_MATCHCASE;
		if (frf.regExp   ) sflags |= SCFIND_REGEXP;

		int max = 40;

		if (frea.all) {
			this.currentSource.sendEditor(SCI_SETCURRENTPOS, 0);
		}

		ttf.lpstrText = toStringz(last_find);
		ttf.chrg.cpMin = this.currentSource.sendEditor(SCI_GETCURRENTPOS);
		ttf.chrg.cpMax = this.currentSource.sendEditor(SCI_GETLENGTH);

		this.currentSource.sendEditor(SCI_FINDTEXT, sflags, cast(int)&ttf);

		this.currentSource.sendEditor(SCI_SETSELECTIONSTART, ttf.chrgText.cpMin);
		this.currentSource.sendEditor(SCI_SETSELECTIONEND, ttf.chrgText.cpMax);

		if (ttf.chrgText.cpMin == ttf.chrgText.cpMax) {
			if (!frea.all) msgBox("Se ha llegado al final del archivo. Se seguirá por el principio.");
		} else {
			this.currentSource.sendEditor(SCI_REPLACESEL, 0, cast(int)toStringz(last_replace));
		}
		
		currentSource.focus();
	}
	
	void showFindReplace_general(bool replace_default) {
		if (!checkSelectedSource) return;
		
		FindReplaceForm frf = new FindReplaceForm(replace_default);
		frf.searcht.text = last_find;
		frf.replacet.text = last_replace;

		frf.onFind ~= &onFindProcess; 
		frf.onReplace ~= &onReplaceProcess; 
		
		frf.show();
	}
	
	void showFindReplace_replace() {
		showFindReplace_general(true);
	}

	void showFindReplace() {
		showFindReplace_general(false);
	}

	void showGotoLine() {
		if (!checkSelectedSource) return;

		GoToForm gotof = new GoToForm(currentSource);
		gotof.line = currentSource.line;
		gotof.showDialog(this);
		if (gotof.accepted && gotof.line != -1) {
			currentSource.line = gotof.line;
			set_jump_caret();
			that.currentSource.sendEditor(SCI_SCROLLCARET);
		}
		currentSource.focus();
	}

	private void processIdx(char[] name) {
		try {
			File f = new File(rootPath ~ "/packages/" ~ name ~ "/help.idx");
			while (!f.eof) {
				try {
					char[] line = f.readLine;
					char[][] chunks = std.string.split(line, "@");
					if (chunks.length > 1) {
						char[] keyword = chunks[0];
						char[][] chunks2 = std.string.split(chunks[1], "::/");
						if (!keyword.length) continue;
						idxList[keyword] = [
							std.string.format("%s\\packages\\%s\\docs\\", rootPath, name, chunks2[0]),
							chunks2[1]
						];
						if (keyword[0] == '$') {
							MenuItem mi = NewMenuItem(keyword[1..keyword.length] ~ "...", delegate void(Object sender, EventArgs ea) {
								MenuItem mi = cast(MenuItem)sender;
								char[] keyword = mi.tag.toString();
								that.openChm(that.idxList[keyword][0], that.idxList[keyword][1]);
							});
							mi.tag = new StringObject(keyword);
							MI["guides"].menuItems.add(mi);
						}
					} else {
						writefln("Format error: %s", chunks[0]);
					}
				} catch (Exception e) {
					writefln("processIdx.Exception[0]: %s", e.toString);
				}
			}
			f.close();
		} catch (Exception e) {
			writefln("processIdx.Exception[1]: %s", e.toString);
		}
	}

	void openChm(char[] chm, char[] page = null) {
		if (!std.file.exists(chm)) return;
		HtmlHelp.DisplayTopic((page is null) ? chm : (chm ~ "::/" ~ page));
	}

	void showHelp() {
		int n; char[] s;
		int start, end, style;
		int maxretry = 4;

		if (currentSource) {
			int pos = currentSource.sendEditor(SCI_GETCURRENTPOS);
			retry:
			start = currentSource.sendEditor(SCI_WORDSTARTPOSITION, pos, true);
			end = currentSource.sendEditor(SCI_WORDENDPOSITION, pos, true);
			style = currentSource.sendEditor(SCI_GETSTYLEAT, start);

			if (style != SCE_C_STRING && style != SCE_C_CHARACTER && style != SCE_C_NUMBER) {
				for (n = start; n < end; n++) s ~= cast(char)currentSource.sendEditor(SCI_GETCHARAT, n);

				for (n = start - 1; n >= 0; n--) {
					if (cast(char)currentSource.sendEditor(SCI_GETCHARAT, n) != '#') break;
					s = "#" ~ s;
				}

				// Preprocesador
				if (s.length == 0 && cast(char)currentSource.sendEditor(SCI_GETCHARAT, pos) == '#') {
					pos++;
					if (maxretry-- > 0) goto retry;
				}

				// Casos especiales # y ## solos
				if (pos > 0 && s.length == 0 && cast(char)currentSource.sendEditor(SCI_GETCHARAT, pos - 1) == '#') s = "#";
				if (cast(char)currentSource.sendEditor(SCI_GETCHARAT, end) == '#') s ~= "#";

				// Comprobamos si está en las listas y en cual de ellas

				/*if (s.length && (s in idxList) is null) {
					msgBox("Identificador '" ~ s ~ "' no está registrado", "Sin ayuda", MsgBoxButtons.OK, MsgBoxIcon.ASTERISK);
					return;
				}*/
			} else if (style == SCE_C_STRING) {
				s = "-escape";
			} else if (style == SCE_C_OPERATOR) {
				s = "-precedence";
			}
		}

		char[] ch;
		char[][] chm = ((s in idxList) !is null) ? idxList[s] : [rootPath ~ "\\packages\\base\\docs\\C.chm", "index.html"];

		if (!std.file.exists(chm[0])) {
			msgBox("No existe '" ~ chm[0] ~ "'", "Sin ayuda", MsgBoxButtons.OK, MsgBoxIcon.ASTERISK);
			return;
		}

		openChm(chm[0], chm[1]);
	}

	private void shortcut_ControlTab(Object sender, FormShortcutEventArgs ea) {
		tc.selectedIndex = (tc.selectedIndex + 1) % tc.tabCount;
	}

	private void shortcut_ControlShiftTab(Object sender, FormShortcutEventArgs ea) {
		tc.selectedIndex = (tc.selectedIndex == 0) ? (tc.tabCount - 1) : (tc.selectedIndex - 1);
	}

	Compiler c;

	void execute(bool save = false) {
		if (!c) {
			c = new Compiler();
			c.packages ~= "win32";
			c.packages ~= "opengl";
			c.packages ~= "sdl";
			c.packages ~= "sdl_image";
			c.packages ~= "sdl_mixer";
			c.packages ~= "sdl_ttf";
			c.packages ~= "sdl_net";
		}

		if (!c.ready) return;

		c.clean();

		if (!checkSelectedSource) return;

		foreach (item; sourceList.items) {
			Source source = cast(Source)item;
			if (source.opened) source.editor.unmarkAll();
		}

		char[][] sources;
		
		try { mkdir(rootPath ~ "\\bin\\temp"); } catch { }

		foreach (item; project.sourceList.items) {
			Source source = cast(Source)item;
			if (source.name.length > 0 && source.name[0] == '.') continue;
			char[] sourcePath = rootPath ~ "\\bin\\temp\\" ~ source.name;
			sources ~= sourcePath;
			write(sourcePath, source.data);
		}

		downSci.readOnly = false;
		downSci.text = "";

		c.compile(sources);

		downSci.text = "\"" ~ c.command ~ "\"";

		if (!c.success) {
			bool moved = false;
			foreach (line; c.errors) {
				char[][] chunks = std.string.split(line, ":");
				int cline = -1;
				if (chunks.length > 2) {
					try {
						cline = std.conv.toInt(chunks[2]) - 1;
						cline = std.conv.toInt(chunks[1]) - 1;
					} catch (Exception e) {
						//writefln("Invalid line: '%s'", chunks[2]);
					}
				}

				char[] error, cfile;

				if (cline != -1) {
					cfile = getBaseName(chunks[1]);
					error = std.string.format("%s:%d:%s", cfile, cline + 1, std.string.join(chunks[3..chunks.length], ":"));
				} else {
					error = line;
				}

				foreach (item; project.sourceList.items) {
					Source source = cast(Source)item;
					if (source.name != cfile) continue;
					source.open();
				}

				//writefln(getBaseName(chunks[1]));

				downSci.text = downSci.text ~ "\n" ~ error;
				currentSource.mark(cline);
				currentSource.selectLine(cline);
				if (!moved) {
					currentSource.gotoLine(cline);
					moved = true;
				}
			}
			status = "Compilacion fallida";
		} else {
			status = "Compilado satisfactoriamente";
		}

		downSci.readOnly = true;

		if (c.success) {
			if (save) {
				c.save(project);
				status = "Guardado ejecutable";
			} else {
				c.execute(project);
			}
		}
	}

	void sci_handleCreated(Object sender, EventArgs ea) {
		//writefln("handled");
	}
}

class Compiler {
	char[] bin;
	char[][] packages = [ "base" ];
	char[][] errors;
	char[] command;
	bool ready = true;
	bool success = false;

	this() {
		bin = rootPath ~ "\\bin\\tcc.exe";
	}

	void clean() {
		char[] rpath = rootPath ~ "\\bin\\temp\\";
		foreach (name; listdir(rpath)) {
			if (name == ".svn") continue;
			try { std.file.remove(rpath ~ name); } catch { }
		}
	}

	void compile(char[][] files) {
		ready = false;

		try {
			char[] pparam = "", sfiles = "";

			foreach (file; files) {
				if (std.string.tolower(std.path.getExt(file)) == "h") continue;
				sfiles ~= " " ~ file;
			}

			success = false;

			foreach (char[] p; packages) {
				pparam ~= std.string.format("-I\"%s\\packages\\%s\\include\" ", rootPath, p);
				//if (p == "base")
				pparam ~= std.string.format("-L\"%s\\packages\\%s\\lib\" ", rootPath, p);
				//pparam ~= std.string.format("-I\"%s\\packages\\%s\\include\\\" -L\"%s\\packages\\%s\\lib\\\" ", rootPath, p, rootPath, p);
			}

			foreach (char[] p; packages) {
				try {
					char[][] libs = std.string.split(cast(char[])std.file.read(std.string.format("%s/packages/%s/libraries", rootPath, p)), "\n");
					//foreach (lib; libs) pparam ~= " -l\"" ~ rootPath ~ "\\packages\\" ~ p ~ "\\lib\\" ~ std.string.strip(lib) ~ "\"";
					foreach (lib; libs) pparam ~= " -l\"" ~ std.string.strip(lib) ~ "\"";
				} catch (Exception e) {
				}
			}

			//writefln("%s", pparam);

			//foreach (rem; [rootPath ~ "\\bin\\temp\\run.exe", rootPath ~ "\\bin\\temp\\run.bat"]) {
			/*foreach (rem; [rootPath ~ "\\bin\\temp\\run.exe"]) {
				if (!rem.exists()) continue;
				std.file.remove(rem);
			}*/

			char[] rcommand;

			try { mkdir(rootPath ~ "\\bin\\temp\\"); } catch { }
			chdir(rootPath ~ "\\bin\\temp\\");

			ProgramPipe pp = new ProgramPipe(rcommand =
				std.string.format(
					"%s %s %s -o %s",
					bin,
					sfiles,
					pparam,
					rootPath ~ "\\bin\\temp\\run.exe"
				)
			);

			writefln("%s", rcommand);

			char[] sfilesc = ""; foreach (file; files) sfilesc ~= getBaseName(file.replace("/", "\\")) ~ " ";

			//command = std.string.format("tcc.exe %s", sfilesc.strip());
			command = std.string.format("tcc.exe %s", sfilesc.strip());

			ubyte[] buffer;

			while (!pp.eof) {
				ubyte[0x400] temp;
				buffer ~= temp[0..pp.read(temp)];
			}

			errors = [];
			Stream f = new MemoryStream(buffer);
			while (!f.eof) errors ~= f.readLine();
			f.close();

			//writefln(errors);

			success = (errors.length == 0);
		} catch (Exception e) {
			errors = [e.toString];
			success = false;
		} finally {
			ready = true;
		}
	}

	void execute(Project project, bool wait = true) {
		if (!success) return;
		success = false;
		//that.downSci

		try {
			chdir(getDirName(project.path));
		} catch (Exception e) {
			chdir(rootPath ~ "\\projects\\");
		}

		wait = that.project.options.getBoolean("common", "wait", true);

		write(rootPath ~ "\\bin\\temp\\run.bat", std.string.format("@echo off\n\"" ~ rootPath ~ "\\bin\\temp\\run.exe\"\n%sexit", wait ? ("\"" ~ rootPath ~ "\\bin\\wait.exe\"\n") : ""));

		try {
			version (zdconsole) {
				std.process.system("start " ~ rootPath ~ "\\bin\\temp\\run.bat");
			} else {
				RunSystemThread rsthread = new RunSystemThread(rootPath ~ "\\bin\\temp\\run.bat");
				rsthread.start();
			}
		} catch (Exception e) {
			msgBox(e.toString);
		}
	}

	void save(Project project) {
		if (!success) return;
		success = false;
		char[] path;
		SaveFileDialog sfd = new SaveFileDialog;
		sfd.filter = "Ejecutable (*.exe)|*.exe|Todos los archivos (*.*)|*.*";
		//sfd.initialDirectory = getDirName(getDirName(Application.executablePath)) ~ "\\projects";
		sfd.initialDirectory = getDirName(project.path);
		sfd.defaultExt = "exe";
		sfd.fileName = project.name ~ ".exe";
		if (DialogResult.OK != sfd.showDialog()) return false;
		path = sfd.fileName;
		if (getExt(path) == null) path ~= ".exe";
		copy(rootPath ~ "\\bin\\temp\\run.exe", path);
	}
}

class RunSystemThread : Thread {
	char[] command;
	this(char[] command) { this.command = command; }
	override int run() {
		int retval = std.process.system(command);

		char[] msg = std.string.format("El programa terminó con el código: %d", retval);

		that.downSci.sendEditor(SCI_APPENDTEXT, msg.length, cast(int)toStringz(msg));

		return retval;
	}
}

char[] openProjectName;

int main(char[][] args) {
	int result = 0;

	try { mkdir(rootPath ~ "\\bin\\temp"); } catch (Exception e) { }

	rootPath = getDirName(getDirName(Application.executablePath));

	if (args.length > 1) {
		switch (std.string.tolower(getExt(args[1]))) {
			// Instalamos pack
			case "tccpack":
				msgBox("pack");
			break;
			// Abrimos proyecto
			case "tccproj": openProjectName = args[1]; break;
			default: break;
		}
	}

	chdir(getDirName(Application.executablePath));

	try {
		associateExtensions();
	} catch {
		writefln("Can't associate extensions (usermode in vista?)");
	}

	try {
		Application.enableVisualStyles();
		Application.run(new MainForm());
	} catch(Object o) {
		msgBox(o.toString(), "Fatal Error", MsgBoxButtons.OK, MsgBoxIcon.ERROR);
		result = 1;
	}

	return result;
}
