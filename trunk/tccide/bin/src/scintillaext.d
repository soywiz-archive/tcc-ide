module dfl.scintillaext;

private import std.stdio, std.ctype, std.string, std.process, std.file;

import dfl.internal.winapi;

public import dfl.scintilla; // DFL control.
public import dfl.cpp.scintilla, dfl.cpp.scilexer; // For scintilla/scite constants.
private import dfl.all;

pragma(lib, "dflscintilla.lib");

extern (C) {
	struct CharacterRange {
	    int cpMin;
	    int cpMax;
	}

	struct TextRange {
	    CharacterRange chrg;
	    char *lpstrText;
	}

	struct TextToFind {
	    CharacterRange chrg;     // range to search
	    char *lpstrText;                // the search pattern (zero terminated)
	    CharacterRange chrgText; // returned as position of matching text
	}
}

class ScintillaExtended : Scintilla {
	this(char[] dll = null) {
		_saved = true;
		if (dll is null) dll = "clex.dll";
		super(dll);
	}

	bool bracehigh(int lpos) {
		char charat = sendEditor(SCI_GETCHARAT, lpos);
		switch (charat) {
			case '(': case ')': case '{': case '}':  case '[': case ']': {
				int rpos = sendEditor(SCI_BRACEMATCH, lpos, 0);
				sendEditor(SCI_BRACEHIGHLIGHT, lpos, rpos);
				return true;
			} break;
			default: break;
		}
		return false;
	}

	bool isLineBeggining() {
		int cpos = sendEditor(SCI_GETCURRENTPOS);
		int cline = sendEditor(SCI_LINEFROMPOSITION, cpos);
		int lstart = sendEditor(SCI_POSITIONFROMLINE, cline);
		//int lend = sendEditor(SCI_GETLINEENDPOSITION, cline);
		for (int lcur = lstart; lcur < cpos; lcur++) {
			if (!isspace(sendEditor(SCI_GETCHARAT, lcur))) return false;
		}
		return true;
	}

	void rtrimLine(int line) {
	}

	/*public void readOnly(bool value) {
		sendEditor(SCI_SETREADONLY, value);
	}

	public bool readOnly() {
		return sendEditor(SCI_GETREADONLY) != 0;
	}*/

	protected override void wndProc(inout Message m) {
	
		switch(m.msg) {
			// KEY_DOWN cursor
			case 256:
				// Tecla arriba
				if (m.wParam == 38) {
					int cpos = sendEditor(SCI_GETCURRENTPOS);
					if (sendEditor(SCI_LINEFROMPOSITION, cpos) == 0) return;
				}
				// Tecla abajo
				else if (m.wParam == 40) {
					int cpos = sendEditor(SCI_GETCURRENTPOS);
					int endline = sendEditor(SCI_LINEFROMPOSITION, sendEditor(SCI_GETLENGTH));
					if (sendEditor(SCI_LINEFROMPOSITION, cpos) == endline) return;
				}
			break;
			// KEY_DOWN
			case 258:
				_saved = false;
				//writefln(m.msg);
				//writefln("lol");
			break;
			// KEY_UP
			case 257:
				//writefln(m.msg);
			break;
			case 275: break;
			case 15: break;
			case 7:
				//writefln("focus");
				//return;
				//Sleep(1000);
			break;
			case 512, 132, 32, 675:
			break;
			case 177:
			return;
			default:
				//writefln(m.msg);
			break;
		}

		super.wndProc(m);

		switch(m.msg) {
			case 513:
			// KEY_DOWN cursor
			case 256:
			case 257:
				int cpos = sendEditor(SCI_GETCURRENTPOS);
				int cline = sendEditor(SCI_LINEFROMPOSITION, cpos);

				if (m.msg == 256) {
					// Enter
					if (m.wParam == 13) {
						for (int line = cline - 1; line >= 0; line--) {
							int lstart = sendEditor(SCI_POSITIONFROMLINE, line);
							int lend = sendEditor(SCI_GETLINEENDPOSITION, line);
							int llstart = lstart;
							int lcur;
							if (lend - lstart == 0) continue;

							for (lcur = lstart; lcur <= lend; lcur++) {
								if (lcur == lend || !isspace(sendEditor(SCI_GETCHARAT, lcur))) { lstart = lcur; break; }
							}

							if (lend - lstart == 0) continue;

							for (lcur = lend - 1; lcur >= lstart; lcur--) {
								if (lcur == lstart || !isspace(sendEditor(SCI_GETCHARAT, lcur))) { lend = lcur; break; }
							}

							//if (lend - lstart == 0) continue;

							char[] adds;
							for (;llstart < lstart; llstart++) adds ~= cast(char)sendEditor(SCI_GETCHARAT, llstart);

							if (sendEditor(SCI_GETCHARAT, lend) == '{') adds ~= "\t";

							sendEditor(SCI_ADDTEXT, adds.length, adds);

							//writefln(lstart, ", ", lend, ",", cast(char)sendEditor(SCI_GETCHARAT, lend));

							break;
						}
						//writefln(cline);
						//writefln(sendEditor(SCI_POSITIONFROMLINE, cline));
						//writefln(sendEditor(SCI_POSITIONFROMLINE, cline - 1));
						//SCI_LINEFROMPOSITION(int pos)
						//SCI_POSITIONFROMLINE(int line)
						//SCI_GETLINEENDPOSITION(int line)
					}

					// Tecla '}'
					if (m.lParam == 0x202B0001) {
						if (isLineBeggining()) {
							sendEditor(SCI_SETSEL, cpos - 1, cpos);
						}
					}
				}

				if (!bracehigh(cpos - 1)) {
					if (!bracehigh(cpos)) {
						sendEditor(SCI_BRACEHIGHLIGHT, -1, -1);
					}
				}
			break;
			// KEY_DOWN
			case 258:
				//writefln(m.msg);
			break;
			// KEY_UP
			//case 257:
				//writefln(m.msg);
			break;
			case 275: break;
			case 15: break;
			default:
			break;
		}
	}

	private int getHexDigit(char d) {
		if (d >= '0' && d <= '9') return d - '0';
		if (d >= 'a' && d <= 'f') return d - 'a' + 10;
		if (d >= 'A' && d <= 'F') return d - 'A' + 10;
		return 0;
	}

	private int getColor(char[] col) {
		int rcol = 0x000000;
		switch (col.length) {
			case 3:
				rcol = Color(
					getHexDigit(col[0]) * 17,
					getHexDigit(col[1]) * 17,
					getHexDigit(col[2]) * 17
				).toRgb();
			break;
			case 6:
				rcol = Color(
					(getHexDigit(col[0]) << 4) | getHexDigit(col[1]),
					(getHexDigit(col[2]) << 4) | getHexDigit(col[3]),
					(getHexDigit(col[4]) << 4) | getHexDigit(col[5])
				).toRgb();
			break;
			default: throw(new Exception("Invalid Color"));
		}
		return rcol;
	}

	private void setStyleColor(int style, int color1, int color2) {
		sendEditor(SCI_STYLESETFORE, style, color1);
		sendEditor(SCI_STYLESETBACK, style, color2);
	}

	private void setStyleColor(int style, char[] color1, char[] color2) {
		sendEditor(SCI_STYLESETFORE, style, getColor(color1));
		sendEditor(SCI_STYLESETBACK, style, getColor(color2));
	}

	private void setStyleColor(int style, int color1) {
		sendEditor(SCI_STYLESETFORE, style, color1);
	}

	private void setStyleColor(int style, char[] color1) {
		sendEditor(SCI_STYLESETFORE, style, getColor(color1));
	}

	protected override void onHandleCreated(EventArgs ea) {
		sendEditor(SCI_SETLEXER, SCLEX_CPP); // Set the lexer. CPP one is for C/C++/D/etc.

		sendEditor(SCI_STYLESETFONT, STYLE_DEFAULT, "Courier New"); // Default font name.
		sendEditor(SCI_STYLESETSIZE, STYLE_DEFAULT, 10); // Default font size.

		setStyleColor(STYLE_BRACELIGHT, Color(0xFF, 0xFF, 0xFF).toRgb(), Color(0x60, 0xA0, 0xFF).toRgb());

		sendEditor(SCI_SETKEYWORDS, 1,
			" register auto extern static inline"
			" const unsigned signed far near"
			" void char short int long float double wchar_t"
		);

		sendEditor(SCI_SETKEYWORDS, 0,
			" struct union enum typedef asm"
			" if else do while for switch case default"
			" goto break continue return"
		);

		setStyleColor(SCE_C_WORD , "0000FF");
		setStyleColor(SCE_C_WORD2, "007FFF");
		setStyleColor(SCE_C_GLOBALCLASS, "7F00FF", "F5EEFF");

		setStyleColor(SCE_P_IDENTIFIER, "3F0000");

		setStyleColor(SCE_C_STRING, "007F00", "F0FFF0");
		setStyleColor(SCE_C_CHARACTER, "00007F", "F0F0FF");
		setStyleColor(SCE_C_PREPROCESSOR, "FF0000", "FFF0F0");

		setStyleColor(SCE_C_COMMENT, "a67632", "fff2e3");
		setStyleColor(SCE_C_COMMENTLINE, "a67632", "fff2e3");
		setStyleColor(SCE_C_COMMENTDOC, "a67632", "fff2e3");

		setStyleColor(SCE_C_ESCAPECHAR, "FF0000");
		setStyleColor(SCE_C_STRINGEOL, "FF0000");
		setStyleColor(SCE_C_VERBATIM, "FF0000");

		setStyleColor(SCE_C_NUMBER, "FF0000");
		setStyleColor(SCE_P_OPERATOR, "00007F");

		sendEditor(SCI_SETTABWIDTH, 4);

		sendEditor(SCI_SETMARGINTYPEN, 1, 1);
		sendEditor(SCI_SETMARGINWIDTHN, 1, 40);

		sendEditor(SCI_SETMARGINLEFT, 0, 10);
		sendEditor(SCI_SETSCROLLWIDTH, 10);

		sendEditor(SCI_MARKERDEFINE, 1, SC_MARK_CIRCLE);

		//autoShow("if do while for");

		super.onHandleCreated(ea);
	}

	void mark(int line) {
		sendEditor(SCI_MARKERADD, line, 1);
		//SCI_MARKERADD(int line, int markerNumber)
	}

	void unmarkAll() {
		sendEditor(SCI_MARKERDELETEALL, -1);
	}

	void gotoLine(int line) {
		if (sendEditor(SCI_LINEFROMPOSITION, sendEditor(SCI_GETCURRENTPOS)) == line) return;
		sendEditor(SCI_GOTOLINE, line);
	}

	int line() {
		return sendEditor(SCI_LINEFROMPOSITION, sendEditor(SCI_GETCURRENTPOS)) + 1;
	}

	void line(int line) {
		gotoLine(line - 1);
	}

	void autoShow(char[] list, char sep = ' ') {
		sendEditor(SCI_AUTOCSETSEPARATOR, sep);
		sendEditor(SCI_AUTOCSHOW, list.length, cast(int)list.ptr);
	}

	override void text(char[] newText) { // setter
		super.text = newText;
		//if (created) sendEditor(SCI_SETSEL, 0, 0);
	}

	override char[] text() { // getter
		return super.text;
	}

	bool _saved;

	bool saved() {
		return _saved;
	}

	bool saved(bool savedNew) {
		_saved = savedNew;
		return _saved;
	}

	/*
	char[] text() {
		char[] data;
		data.length = sendEditor(SCI_GETLENGTH) + 1;
		sendEditor(SCI_GETTEXT, data.length, cast(int)data.ptr);
		data.length = data.length - 1;
		return data;
	}

	char[] text(char[] text) {
		sendEditor(SCI_SETTEXT, text.length, cast(int)text.ptr);
		return text;
	}
	*/

	void selectLine(int line) {
		int startLine = sendEditor(SCI_POSITIONFROMLINE, line);
		int endLine = sendEditor(SCI_GETLINEENDPOSITION, line);
		sendEditor(SCI_SETSELECTIONSTART, startLine);
		sendEditor(SCI_SETSELECTIONEND, endLine);
	}
	
	/*override void wndProc(inout Message m) {
		//.writefln("message");
		//super.wndProc(m);
		super.wndProc(m);
	}*/
}

static this() {
	writefln("lol");
}