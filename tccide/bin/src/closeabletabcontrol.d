module dfl.closeabletabcontrol;

private import std.stdio, std.ctype, std.string, std.process, std.file, std.c.windows.windows;
private import std.c.stdio, std.c.stdlib;
private import std.stream, std.conv, std.gc;

private import dfl.all;
private import dfl.internal.winapi, dfl.internal.wincom;

class CloseableTabEventArgs : EventArgs {
	this(CloseableTabControl ctb, int tabIndex, TabPage tabPage) {
		_ctb = ctb;
		_tabIndex = tabIndex;
		_tabPage = tabPage;
	}

	int tabIndex() { return _tabIndex; }
	TabPage tabPage() { return _tabPage; }

	void allow(bool allowClose = true) {
		_ctb.allowClose = allowClose;
	}

	public CloseableTabControl _ctb;
	private int _tabIndex;
	private TabPage _tabPage;
}

class CloseableTabControl : TabControl {
	Event!(CloseableTabControl, CloseableTabEventArgs) beforeCloseTab;
	Event!(CloseableTabControl, CloseableTabEventArgs) afterCloseTab;

	bool allowClose;

	void onMouseDown(MouseEventArgs mea) {
		scope (exit) super.onMouseDown(mea);

		// Check that the button pressed was the middle one
		if (mea.button != MouseButtons.MIDDLE) return;

		// Performs a binary search to determine which tab is affected
		int max = tabCount, min = 0, cur, mcyc = 10;
		bool found = false;

		while (min != max + 1 && mcyc-- > 0) {
			cur = (max + min) / 2;
			Rect cs = getTabRect(cur);
			if (cs.contains(mea.x, mea.y)) { found = true; break; }
			if (mea.x < cs.x) max = cur - 1; else min = cur + 1;
		}

		// Checks that found a tab
		if (!found) return;

		allowClose = true;

		TabPage tab = tabPages[cur];

		beforeCloseTab(this, new CloseableTabEventArgs(this, cur, tab));

		if (!allowClose) return;

		if (cur == selectedIndex) selectedIndex = ((selectedIndex > 0) ? selectedIndex : tabCount) - 1;
		tabPages.removeAt(cur);

		afterCloseTab(this, new CloseableTabEventArgs(this, -1, tab));

		onSelectedIndexChanged(EventArgs.empty);
	};
}

/*
	beforeCloseTab ~= delegate void(CloseableTabControl c, CloseableTabEventArgs ctea) {
		ctea.allow = (msgBox("Close '" ~ ctea.tabPage.text ~ "' tab?", "Warning", MsgBoxButtons.OK_CANCEL, MsgBoxIcon.ASTERISK) == DialogResult.OK);
	};

	afterCloseTab ~= delegate void(CloseableTabControl ctc, CloseableTabEventArgs ctea) {
		ctc.selectedTab.focus();
		msgBox("Tab Cloed");
	};
*/