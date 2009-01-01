module gotoform;

private import std.stdio, std.ctype, std.string, std.process, std.file, std.c.windows.windows;
private import std.c.stdio, std.c.stdlib;
private import std.stream, std.conv, std.gc;

private import dfl.scintillaext, dfl.splitterext, dfl.closeabletabcontrol;
private import dfl.all;
private import dfl.internal.winapi, dfl.internal.wincom;

class GoToForm : dfl.form.Form {
	dfl.textbox.TextBox value;
	dfl.button.Button accept;
	dfl.button.Button cancel;

	bool accepted = false;

	this(ScintillaExtended sci) {
		controlBox = false;
		formBorderStyle = dfl.form.FormBorderStyle.FIXED_DIALOG;
		maximizeBox = false;
		minimizeBox = false;
		opacity = 0.80;
		showInTaskbar = false;

		startPosition = dfl.form.FormStartPosition.CENTER_PARENT;
		text = "Ir a línea";
		topMost = true;
		clientSize = dfl.drawing.Size(166, 70);
		value = new dfl.textbox.TextBox();
		value.bounds = Rect(8, 8, 80, 24);
		value.parent = this;
		accept = new dfl.button.Button();
		accept.text = "Ir a";
		accept.bounds = Rect(96, 8, 64, 24);
		accept.parent = this;
		accept.click ~= &onAccept;
		cancel = new dfl.button.Button();
		cancel.text = "Cancelar";
		cancel.bounds = Rect(96, 40, 64, 24);
		cancel.parent = this;
		cancel.click ~= &onAccept;

		this.acceptButton = accept;
		this.cancelButton = cancel;
	}

	override void onActivated(EventArgs ea) {
		value.focus();
		value.select();
		super.onActivated(ea);
	}

	void onAccept(Control sender, EventArgs ea) {
		if (sender == cast(Control)accept) accepted = true;
		close();
	}

	int line() {
		try {
			return std.conv.toInt(value.text);
		} catch (Exception e) {
			return -1;
		}
	}

	void line(int l) {
		value.text = std.string.format("%d", l);
		value.focus();
	}
}