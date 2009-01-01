module dfl.splitterext;

private import std.stdio, std.ctype, std.string, std.process, std.file, std.c.windows.windows;
private import std.c.stdio, std.c.stdlib;
private import std.stream, std.conv, std.gc;

private import dfl.scintillaext;
private import dfl.all;
private import dfl.internal.winapi, dfl.internal.wincom;

class SplitterExt : Splitter {
	int defaultPos = 180;

	void onDoubleClick(EventArgs ea) {
		int size;

		switch (dock) {
			case DockStyle.LEFT   : size = left; break;
			case DockStyle.RIGHT  : size = parent.clientSize.width - left; break;
			case DockStyle.TOP    : size = top; break;
			case DockStyle.BOTTOM : size = parent.clientSize.height - top; break;
		}

		splitPosition = (size > defaultPos / 2) ? 0 : defaultPos;

		super.onDoubleClick(ea);
	}

	/+
	final void splitPosition(int pos) // setter
	{
		int x, y;

		switch (dock) {
			case DockStyle.LEFT:
				x = pos - left;
			break;
			case DockStyle.RIGHT:
				return;
			break;
			case DockStyle.TOP:
				y = pos - top;
			break;
			case DockStyle.BOTTOM:
				return;
				/*
				y = top - pos;
				//writefln("(%d) %d, %d, %d, %d", defaultPos, y, pos, top, height);
				writefln("->%d, %d", top, pos);
				*/
			break;
		}

		scope mea = new MouseEventArgs(MouseButtons.LEFT, 1, x, y, 0);
		onMouseUp(mea);
	}

	/// ditto
	// -1 if not docked to a control.
	final int splitPosition() // getter
	{
		return left;
	}
	+/
}