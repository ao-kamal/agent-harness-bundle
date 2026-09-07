using System;
using System.IO;
using System.Runtime.InteropServices;

class GetClip {
    [DllImport("user32.dll")]
    static extern bool OpenClipboard(IntPtr hWndNewOwner);

    [DllImport("user32.dll")]
    static extern bool CloseClipboard();

    [DllImport("user32.dll")]
    static extern IntPtr GetClipboardData(uint uFormat);

    [DllImport("kernel32.dll")]
    static extern IntPtr GlobalLock(IntPtr hMem);

    [DllImport("kernel32.dll")]
    static extern bool GlobalUnlock(IntPtr hMem);

    const uint CF_UNICODETEXT = 13;

    [STAThread]
    static void Main() {
        for (int i = 0; i < 10; i++) {
            if (OpenClipboard(IntPtr.Zero)) {
                try {
                    IntPtr handle = GetClipboardData(CF_UNICODETEXT);
                    if (handle != IntPtr.Zero) {
                        IntPtr pointer = GlobalLock(handle);
                        if (pointer != IntPtr.Zero) {
                            try {
                                string text = Marshal.PtrToStringUni(pointer);
                                if (text != null) {
                                    Console.OutputEncoding = System.Text.Encoding.UTF8;
                                    Console.Write(text);
                                }
                            } finally {
                                GlobalUnlock(handle);
                            }
                        }
                    }
                } finally {
                    CloseClipboard();
                }
                return;
            }
            System.Threading.Thread.Sleep(10);
        }
    }
}
