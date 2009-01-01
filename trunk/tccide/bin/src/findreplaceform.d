module findreplaceform;

private import std.stdio, std.ctype, std.string, std.process, std.file, std.c.windows.windows;
private import std.c.stdio, std.c.stdlib;
private import std.stream, std.conv, std.gc;

private import dfl.scintillaext, dfl.splitterext, dfl.closeabletabcontrol;
private import dfl.all;
private import dfl.internal.winapi, dfl.internal.wincom;

class FindReplaceEventArgs : EventArgs {
	char[] find;
	char[] replace;
	bool all;

	this(char[] find, char[] replace = "", bool all = false) {
		this.find = find;
		this.replace = replace;
		this.all = all;
	}
}

class FindReplaceForm : dfl.form.Form {
	Event!(FindReplaceForm, FindReplaceEventArgs) onFind;
	Event!(FindReplaceForm, FindReplaceEventArgs) onReplace;

	dfl.label.Label label1;
	dfl.label.Label label2;

	dfl.button.Button searchb;
	dfl.button.Button replaceb;
	dfl.button.Button replaceallb;
	dfl.button.Button cancelb;

	dfl.combobox.ComboBox searcht;
	dfl.combobox.ComboBox replacet;
	dfl.button.CheckBox maymincb;
	dfl.button.CheckBox regexpcb;

	bool matchCase() {
		return maymincb.checked;
	}

	bool regExp() {
		return regexpcb.checked;
	}

	this(bool replace_default) {
		topMost = true;
		showInTaskbar = false;

		startPosition = dfl.form.FormStartPosition.CENTER_PARENT;
		text = "Buscar y Reemplazar";

		clientSize = dfl.drawing.Size(402, 149);

		label1 = new dfl.label.Label();
		label1.text = "Buscar:";
		label1.textAlign = dfl.base.ContentAlignment.MIDDLE_LEFT;
		label1.bounds = Rect(16, 19, 60, 16);
		label1.parent = this;

		label2 = new dfl.label.Label();
		label2.text = "Reemplazar:";
		label2.textAlign = dfl.base.ContentAlignment.MIDDLE_LEFT;
		label2.bounds = Rect(16, 50, 60, 16);
		label2.parent = this;

		searcht = new dfl.combobox.ComboBox();
		searcht.bounds = Rect(88, 16, 192, 21);
		searcht.parent = this;

		replacet = new dfl.combobox.ComboBox();
		replacet.bounds = Rect(88, 48, 192, 21);
		replacet.parent = this;

		searchb = new dfl.button.Button();
		searchb.text = "&Buscar siguiente";
		searchb.bounds = Rect(288, 16, 104, 24);
		searchb.parent = this;
		searchb.click ~= &w_onFind;

		replaceb = new dfl.button.Button();
		replaceb.text = "&Reemplazar";
		replaceb.bounds = Rect(288, 48, 104, 24);
		replaceb.parent = this;
		replaceb.click ~= &w_onReplace;

		replaceallb = new dfl.button.Button();
		replaceallb.text = "Reemplazar &Todo";
		replaceallb.bounds = Rect(288, 80, 104, 24);
		replaceallb.parent = this;
		replaceallb.click ~= &w_onReplaceAll;
		replaceallb.enabled = false;

		cancelb = new dfl.button.Button();
		cancelb.text = "&Cancelar";
		cancelb.bounds = Rect(288, 112, 104, 24);
		cancelb.parent = this;
		cancelb.click ~= &onCancelButton;

		maymincb = new dfl.button.CheckBox();
		maymincb.text = "Considerar &Mayúsculas/Minúsculas";
		maymincb.bounds = Rect(16, 84, 264, 16);
		maymincb.parent = this;

		regexpcb = new dfl.button.CheckBox();
		regexpcb.text = "Usar &expresiones regulares";
		regexpcb.bounds = Rect(16, 112, 264, 16);
		regexpcb.parent = this;

		// Other MyForm initialization code here.
		if (replace_default) {
			this.acceptButton = replaceb;
		} else {
			this.acceptButton = searchb;
		}
		this.cancelButton = cancelb;

		controlBox = false;
		formBorderStyle = dfl.form.FormBorderStyle.FIXED_DIALOG;
		maximizeBox = false;
		minimizeBox = false;
		opacity = 0.80;
	}

	void w_onFind(Object sender, EventArgs ea) {
		onFind(this, new FindReplaceEventArgs(searcht.text));
		searcht.focus();
	}

	void w_onReplace(Object sender, EventArgs ea) {
		onReplace(this, new FindReplaceEventArgs(searcht.text, replacet.text, false));
		replacet.focus();
	}

	void w_onReplaceAll(Object sender, EventArgs ea) {
		onReplace(this, new FindReplaceEventArgs(searcht.text, replacet.text, true));
		replacet.focus();
	}

	void onCancelButton(Object sender, EventArgs ea) {
		close();
	}

	override void onActivated(EventArgs ea) {
		searcht.focus();
		searcht.select();
		opacity = 0.8;
		super.onActivated(ea);
	}

	override void onDeactivate(EventArgs ea) {
		searcht.focus();
		searcht.select();
		opacity = 0.2;
		super.onDeactivate(ea);
	}
}
