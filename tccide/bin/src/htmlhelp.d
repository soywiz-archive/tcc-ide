module htmlhelp;

private import std.stdio, std.ctype, std.string, std.process, std.file, std.c.windows.windows;
private import std.c.stdio, std.c.stdlib, std.path, std.zip;
private import std.stream, std.conv, std.gc, std.thread;

private import dfl.scintillaext, dfl.splitterext, dfl.closeabletabcontrol;
private import dfl.all;
private import dfl.internal.winapi, dfl.internal.wincom;

class HtmlHelp {
	static HINSTANCE ihl;
	static HWND handle;

	static struct HH_POPUP {
		int         cbStruct;
		HINSTANCE   hinst;
		UINT        idString;
		LPCTSTR     pszText;
		POINT       pt;
		COLORREF    clrForeground;
		COLORREF    clrBackground;
		RECT        rcMargins;
		LPCTSTR     pszFont;
	}

	static struct HH_WINTYPE {
	     int           cbStruct;
	     BOOL          fUniCodeStrings;
	     LPCTSTR       pszType;
	     DWORD         fsValidMembers;
	     DWORD         fsWinProperties;
	     LPCTSTR       pszCaption;
	     DWORD         dwStyles;
	     DWORD         dwExStyles;
	     RECT          rcWindowPos;
	     int           nShowState;
	     HWND          hwndHelp;
	     HWND          hwndCaller;
	     HWND          hwndToolBar;
	     HWND          hwndNavigation;
	     HWND          hwndHTML;
	     int           iNavWidth;
	     RECT          rcHTML;
	     LPCTSTR       pszToc;
	     LPCTSTR       pszIndex;
	     LPCTSTR       pszFile;
	     LPCTSTR       pszHome;
	     DWORD         fsToolBarFlags;
	     BOOL          fNotExpanded;
	     int           curNavType;
	     int           idNotify;
	     LPCTSTR       pszJump1;
	     LPCTSTR       pszJump2;
	     LPCTSTR       pszUrlJump1;
	     LPCTSTR       pszUrlJump2;
	}

	struct HH_AKLINK {
		int      cbStruct;
		BOOL     fReserved;
		LPCTSTR  pszKeywords;
		LPCTSTR  pszUrl;
		LPCTSTR  pszMsgText;
		LPCTSTR  pszMsgTitle;
		LPCTSTR  pszWindow;
		BOOL     fIndexOnFail;
	}

	struct HHN_NOTIFY {
		NMHDR  hdr;
		PCSTR  pszUrl;
	}

	struct HHNTRACK {
		NMHDR       hdr;
		PCSTR       pszCurUrl;
		int         idAction;
		HH_WINTYPE* phhWinType;
	}

	struct HH_FTS_QUERY {
		int      cbStruct;
		BOOL     fUniCodeStrings;
		LPCTSTR  pszSearchQuery;
		LONG     iProximity;
		BOOL     fStemmedSearch;
		BOOL     fTitleOnly;
		BOOL     fExecute;
		LPCTSTR  pszWindow;
	}

	struct HH_LAST_ERROR {
		int      cbStruct;
		HRESULT  hr;
		LPCTSTR  description;
	}

	enum {
		HH_DISPLAY_TOPIC      = 0x0000,
		HH_DISPLAY_TOC        = 0x0001,
		HH_DISPLAY_INDEX      = 0x0002,
		HH_DISPLAY_SEARCH     = 0x0003,
		HH_SET_WIN_TYPE       = 0x0004,
		HH_GET_WIN_TYPE       = 0x0005,
		HH_GET_WIN_HANDLE     = 0x0006,
		HH_GET_INFO_TYPES     = 0x0007,
		HH_SET_INFO_TYPES     = 0x0008,
		HH_SYNC               = 0x0009,
		HH_ADD_NAV_UI         = 0x000A,
		HH_ADD_BUTTON         = 0x000B,
		HH_GETBROWSER_APP     = 0x000C,
		HH_KEYWORD_LOOKUP     = 0x000D,
		HH_DISPLAY_TEXT_POPUP = 0x000E,
		HH_HELP_CONTEXT       = 0x000F,
	}

	enum {
		HHWIN_NAVTYPE_TOC,
		HHWIN_NAVTYPE_INDEX,
		HHWIN_NAVTYPE_SEARCH,
		HHWIN_NAVTYPE_FAVORITES,
		HHWIN_NAVTYPE_HISTORY,   // not
		HHWIN_NAVTYPE_AUTHOR,
		HHWIN_NAVTYPE_CUSTOM_FIRST = 11
	};

	enum {
		HHWIN_PROP_ONTOP          = (1 <<  1),
		HHWIN_PROP_NOTITLEBAR     = (1 <<  2),
		HHWIN_PROP_NODEF_STYLES   = (1 <<  3),
		HHWIN_PROP_NODEF_EXSTYLES = (1 <<  4),
		HHWIN_PROP_TRI_PANE       = (1 <<  5),
		HHWIN_PROP_NOTB_TEXT      = (1 <<  6),
		HHWIN_PROP_POST_QUIT      = (1 <<  7),
		HHWIN_PROP_AUTO_SYNC      = (1 <<  8),
		HHWIN_PROP_TRACKING       = (1 <<  9),
		HHWIN_PROP_TAB_SEARCH     = (1 << 10),
		HHWIN_PROP_TAB_HISTORY    = (1 << 11),
		HHWIN_PROP_TAB_FAVORITES  = (1 << 12),
		HHWIN_PROP_CHANGE_TITLE   = (1 << 13),
		HHWIN_PROP_NAV_ONLY_WIN   = (1 << 14),
		HHWIN_PROP_NO_TOOLBAR     = (1 << 15),
	}

	enum {
		HHWIN_PARAM_PROPERTIES    = (1 <<   1),
		HHWIN_PARAM_STYLES        = (1 <<   2),
		HHWIN_PARAM_EXSTYLES      = (1 <<   3),
		HHWIN_PARAM_RECT          = (1 <<   4),
		HHWIN_PARAM_NAV_WIDTH     = (1 <<   5),
		HHWIN_PARAM_SHOWSTATE     = (1 <<   6),
		HHWIN_PARAM_INFOTYPES     = (1 <<   7),
		HHWIN_PARAM_TB_FLAGS      = (1 <<   8),
		HHWIN_PARAM_EXPANSION     = (1 <<   9),
		HHWIN_PARAM_TABPOS        = (1 <<  10),
		HHWIN_PARAM_TABORDER      = (1 <<  11),
		HHWIN_PARAM_HISTORY_COUNT = (1 <<  12),
		HHWIN_PARAM_CUR_TAB       = (1 <<  13),
	}

	enum {
		HHWIN_BUTTON_EXPAND     = (1 <<   1),
		HHWIN_BUTTON_BACK       = (1 <<   2),
		HHWIN_BUTTON_FORWARD    = (1 <<   3),
		HHWIN_BUTTON_STOP       = (1 <<   4),
		HHWIN_BUTTON_REFRESH    = (1 <<   5),
		HHWIN_BUTTON_HOME       = (1 <<   6),
		HHWIN_BUTTON_BROWSE_FWD = (1 <<   7),
		HHWIN_BUTTON_BROWSE_BCK = (1 <<   8),
		HHWIN_BUTTON_NOTES      = (1 <<   9),
		HHWIN_BUTTON_CONTENTS   = (1 <<  10),
		HHWIN_BUTTON_SYNC       = (1 <<  11),
		HHWIN_BUTTON_OPTIONS    = (1 <<  12),
		HHWIN_BUTTON_PRINT      = (1 <<  13),
		HHWIN_BUTTON_INDEX      = (1 <<  14),
		HHWIN_BUTTON_SEARCH     = (1 <<  15),
		HHWIN_BUTTON_HISTORY    = (1 <<  16),
		HHWIN_BUTTON_FAVORITES  = (1 <<  17),
		HHWIN_BUTTON_JUMP1      = (1 <<  18),
		HHWIN_BUTTON_JUMP2      = (1 <<  19),
		HHWIN_BUTTON_ZOOM       = (1 <<  20),
		HHWIN_BUTTON_TOC_NEXT   = (1 <<  21),
		HHWIN_BUTTON_TOC_PREV   = (1 <<  22),
	}

	enum {
		IDTB_EXPAND      = 200,
		IDTB_CONTRACT    = 201,
		IDTB_STOP        = 202,
		IDTB_REFRESH     = 203,
		IDTB_BACK        = 204,
		IDTB_HOME        = 205,
		IDTB_SYNC        = 206,
		IDTB_PRINT       = 207,
		IDTB_OPTIONS     = 208,
		IDTB_FORWARD     = 209,
		IDTB_NOTES       = 210,
		IDTB_BROWSE_FWD  = 211,
		IDTB_BROWSE_BACK = 212,
		IDTB_CONTENTS    = 213,
		IDTB_INDEX       = 214,
		IDTB_SEARCH      = 215,
		IDTB_HISTORY     = 216,
		IDTB_FAVORITES   = 217,
		IDTB_JUMP1       = 218,
		IDTB_JUMP2       = 219,
		IDTB_CUSTOMIZE   = 221,
		IDTB_ZOOM        = 222,
		IDTB_TOC_NEXT    = 223,
		IDTB_TOC_PREV    = 224,
	}

	const uint HHWIN_DEF_BUTTONS = HHWIN_BUTTON_EXPAND | HHWIN_BUTTON_BACK | HHWIN_BUTTON_OPTIONS | HHWIN_BUTTON_PRINT;

	const uint HHN_FIRST = -860;
	const uint HHN_LAST  = -879;

	const uint HHN_NAVCOMPLETE   = (HHN_FIRST - 0);
	const uint HHN_TRACK         = (HHN_FIRST - 1);
	const uint HHN_WINDOW_CREATE = (HHN_FIRST - 2);

	extern (Windows) {
		typedef HWND function(HWND hwndCaller, LPCSTR pszFile, UINT uCommand, DWORD *dwData) p_HtmlHelpA;
		typedef HRESULT function() p_DllRegisterServer;
		typedef HRESULT function() p_DllUnregisterServer;
		static p_HtmlHelpA HtmlHelpA;
		static p_DllRegisterServer DllRegisterServer;
		static p_DllUnregisterServer DllUnregisterServer;
	}

	static void Register(HWND handle = null) {
		if ((ihl = LoadLibraryA("HHCTRL.OCX")) is null) return;

		HtmlHelpA = cast(p_HtmlHelpA)GetProcAddress(ihl, "HtmlHelpA");
		DllRegisterServer = cast(p_DllRegisterServer)GetProcAddress(ihl, "DllRegisterServer");
		DllUnregisterServer = cast(p_DllUnregisterServer)GetProcAddress(ihl, "DllUnregisterServer");

		if (DllRegisterServer) DllRegisterServer();

		this.handle = handle;
	}

	static void Unregister() {
		if (DllUnregisterServer) DllUnregisterServer();
		if (ihl) FreeLibrary(ihl);
	}

	static HWND Send(char[] file, UINT uCommand, void *dwData = null) {
		if (!HtmlHelpA) return null;
		return HtmlHelpA(handle, toStringz(file), uCommand, cast(DWORD *)dwData);
	}

	// Commands
	static HWND DisplayTopic(char[] file) {
		return Send(file, HH_DISPLAY_TOPIC, null);
	}

	static HWND KeywordLookup(char[] file, char[] keywords) {
		HH_AKLINK link;
		link.cbStruct     = HH_AKLINK.sizeof;
		//link.fReserved    = false;
		link.pszKeywords  = toStringz(keywords);
		//link.pszUrl       = null;
		//link.pszMsgText   = null;
		//link.pszMsgTitle  = null;
		//link.pszWindow    = null;
		link.fIndexOnFail = true;

		return Send(file, HH_KEYWORD_LOOKUP, &link);
	}
}
