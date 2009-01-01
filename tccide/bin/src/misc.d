module misc;

import std.stream, std.c.windows.windows, std.string, std.stdio;
import std.c.stdlib;

extern (Windows) {
	struct STARTUPINFO {
		DWORD cb;
		LPTSTR lpReserved;
		LPTSTR lpDesktop;
		LPTSTR lpTitle;
		DWORD dwX;
		DWORD dwY;
		DWORD dwXSize;
		DWORD dwYSize;
		DWORD dwXCountChars;
		DWORD dwYCountChars;
		DWORD dwFillAttribute;
		DWORD dwFlags;
		WORD wShowWindow;
		WORD cbReserved2;
		LPBYTE lpReserved2;
		HANDLE hStdInput;
		HANDLE hStdOutput;
		HANDLE hStdError;
	}

	struct PROCESS_INFORMATION {
		HANDLE hProcess;
		HANDLE hThread;
		DWORD dwProcessId;
		DWORD dwThreadId;
	}

	BOOL GetExitCodeProcess(HANDLE hProcess, LPDWORD lpExitCode);
	BOOL CreatePipe(HANDLE*,HANDLE*,LPSECURITY_ATTRIBUTES,DWORD);
	BOOL CreateProcessA(LPCSTR,LPSTR,LPSECURITY_ATTRIBUTES,LPSECURITY_ATTRIBUTES,BOOL,DWORD,PVOID,LPCSTR,STARTUPINFO*,PROCESS_INFORMATION*);
	alias CreateProcessA CreateProcess;
	BOOL PeekNamedPipe(HANDLE,PVOID,DWORD,PDWORD,PDWORD,PDWORD);

	const int DUPLICATE_CLOSE_SOURCE = 0x00000001;
	const int DUPLICATE_SAME_ACCESS  = 0x00000002;

	const int STARTF_USESHOWWINDOW = 1;
	const int STARTF_USESTDHANDLES = 256;

	const int STILL_ACTIVE = 0x103;

	const int NORMAL_PRIORITY_CLASS = 0x00000020;
	const int CREATE_NO_WINDOW = 0x08000000;
}

class Pipe {
	HANDLE h_write, h_read;

	private void duplicate(HANDLE *handle) {
		DuplicateHandle(GetCurrentProcess(), *handle, GetCurrentProcess(), handle, 0, true, DUPLICATE_CLOSE_SOURCE | DUPLICATE_SAME_ACCESS);
	}

	this() {
		CreatePipe(&h_read, &h_write, null, 0x1000);
		duplicate(&h_write);
		duplicate(&h_read);
	}

	~this() {
		CloseHandle(h_read);
		CloseHandle(h_write);
	}
}

class ProgramPipe : Stream {
	STARTUPINFO siStartInfo;
	PROCESS_INFORMATION piProcInfo;
	char[] program;
	Pipe stdout;
	Pipe stdin;
	bool _eof;

	bool eof() {
		if (available > 0) return false;
		if (_eof) return true;
		DWORD exitCode;
		if (GetExitCodeProcess(piProcInfo.hProcess, &exitCode) != 0 && exitCode != STILL_ACTIVE) _eof = true;
		return _eof;
	}

	this(char[] program) {
		stdin  = new Pipe;
		stdout = new Pipe;

		with (siStartInfo) {
			cb         = STARTUPINFO.sizeof;
			dwFlags   |= STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES;
			hStdInput  = stdin.h_read;
			hStdError  = stdout.h_write;
			hStdOutput = stdout.h_write;
		}

		this.program = program;

		CreateProcess(null,
			toStringz(program),
			null,
			null,
			true,
			NORMAL_PRIORITY_CLASS | CREATE_NO_WINDOW,
			null,
			null,
			&siStartInfo,
			&piProcInfo
		);
	}

	~this() {
		delete stdin;
		delete stdout;
	}

	uint available() {
		//if (eof) return 0;
		uint available;
		PeekNamedPipe(stdout.h_read, null, 0, null, &available, null);
		return available;
	}

	uint readBlock(void* buffer, uint size) {
		uint max = available, readed;
		if (max == 0) return 0;
		if (size > max) size = max;
		ReadFile(stdout.h_read, buffer, size, &readed, null);
		return readed;
	}

	uint writeBlock(void* buffer, uint size) {
		uint writed;
		WriteFile(stdin.h_write, buffer, size, &writed, null);
		return writed;
	}


	ulong seek(long offset, SeekPos whence) {
		return 0;
	}
}
