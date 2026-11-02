#!/usr/bin/env python3
"""Small, dependency-free desktop build panel for macOS and Windows."""
from pathlib import Path
import platform
import queue
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import ttk

ROOT = Path(__file__).resolve().parents[1]
BG, PANEL, FG, MUTED, MINT = "#080e0c", "#14201b", "#edf7f1", "#b5c8bc", "#7affbf"


class Builder:
    def __init__(self):
        self.window = tk.Tk()
        self.window.title("AI Mắt · IPA Builder")
        self.window.geometry("720x660")
        self.window.minsize(600, 620)
        self.window.configure(bg=BG)
        self.events = queue.Queue()
        self.busy = False
        self.buttons = []
        self.team = tk.StringVar()
        self.bundle = tk.StringVar(value="vn.aimat.camera")
        self.method = tk.StringVar(value="debugging")
        self.label("AI MẮT", 26, MINT).pack(anchor="w", padx=28, pady=(26, 4))
        self.label("COMPACT IPA BUILDER", 10, MUTED).pack(anchor="w", padx=28)
        notice = ("macOS · Xcode sẽ biên dịch và ký ứng dụng bằng tài khoản của bạn." if platform.system() == "Darwin"
                  else "Windows · Chuẩn bị mã nguồn tại đây. Biên dịch IPA trên Mac hoặc GitHub Actions.")
        self.label(notice, 11, MUTED, wraplength=650).pack(anchor="w", padx=28, pady=(18, 12))
        fields = tk.Frame(self.window, bg=PANEL, padx=16, pady=12)
        fields.pack(fill="x", padx=28)
        for row, (title, variable) in enumerate([("Apple Team ID", self.team), ("Bundle ID", self.bundle)]):
            tk.Label(fields, text=title, bg=PANEL, fg=FG, anchor="w", font=("Segoe UI", 11)).grid(row=row, column=0, sticky="w", padx=(0, 18), pady=6)
            tk.Entry(fields, textvariable=variable, bg=BG, fg=FG, insertbackground=MINT, relief="flat", font=("Segoe UI", 11)).grid(row=row, column=1, sticky="ew", ipady=7, pady=6)
        tk.Label(fields, text="Phân phối", bg=PANEL, fg=FG, font=("Segoe UI", 11)).grid(row=2, column=0, sticky="w", pady=6)
        ttk.Combobox(fields, textvariable=self.method, values=["debugging", "release-testing", "app-store-connect"], state="readonly").grid(row=2, column=1, sticky="ew", ipady=4)
        fields.columnconfigure(1, weight=1)
        actions = tk.Frame(self.window, bg=BG)
        actions.pack(fill="x", padx=28, pady=16)
        for title, action in [("Chuẩn bị", "prepare"), ("Kiểm tra", "check"), ("Gói mã nguồn", "source"), ("Build IPA có ký", "ipa")]:
            button = tk.Button(actions, text=title, command=lambda value=action: self.build(value), bg=MINT if action == "ipa" else PANEL,
                fg=BG if action == "ipa" else FG, activebackground=MINT, activeforeground=BG,
                relief="flat", padx=12, pady=12, font=("Segoe UI", 10, "bold"), cursor="hand2")
            button.pack(side="left", padx=(0, 8))
            self.buttons.append(button)
        self.status = self.label("Sẵn sàng. Không cần cài thư viện Python ngoài.", 11, MINT)
        self.status.pack(anchor="w", padx=28, pady=(0, 10))
        self.log = tk.Text(self.window, bg="#050907", fg=MUTED, insertbackground=MINT, relief="flat", font=("Consolas", 10), padx=12, pady=12, wrap="word", height=13)
        self.log.pack(fill="both", expand=True, padx=28, pady=(0, 12))
        self.label("IPA cần chứng chỉ và provisioning hợp lệ. Công cụ không tải bản build lên App Store.", 10, MUTED, wraplength=650).pack(anchor="w", padx=28, pady=(0, 20))
        self.window.after(100, self.poll)

    def label(self, text, size, color, **kwargs):
        return tk.Label(self.window, text=text, bg=BG, fg=color, font=("Segoe UI", size), justify="left", **kwargs)

    def build(self, action):
        if self.busy: return
        command = [sys.executable, "-u", str(ROOT / "scripts/build.py"), action]
        if action == "ipa":
            command += ["--team", self.team.get().strip(), "--bundle-id", self.bundle.get().strip(), "--method", self.method.get()]
        self.busy = True
        for button in self.buttons: button.configure(state="disabled")
        self.status.configure(text="Đang xử lý…")
        self.log.delete("1.0", "end")
        threading.Thread(target=self.worker, args=(command,), daemon=True).start()

    def worker(self, command):
        try:
            options = {"creationflags": subprocess.CREATE_NO_WINDOW} if platform.system() == "Windows" else {}
            with subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, encoding="utf-8", errors="replace", env=self.child_env(), **options) as process:
                for line in process.stdout: self.events.put(("log", line))
                result = process.wait()
            self.events.put(("done", result))
        except Exception as error:
            self.events.put(("log", str(error) + "\n"))
            self.events.put(("done", 1))

    @staticmethod
    def child_env():
        import os
        return dict(os.environ, PYTHONIOENCODING="utf-8", PYTHONUTF8="1")

    def poll(self):
        while not self.events.empty():
            event, value = self.events.get_nowait()
            if event == "log": self.log.insert("end", value); self.log.see("end")
            else:
                self.busy = False
                self.status.configure(text="Hoàn tất." if value == 0 else "Chưa hoàn tất — xem hướng dẫn trong nhật ký.")
                for button in self.buttons: button.configure(state="normal")
        self.window.after(100, self.poll)


if __name__ == "__main__":
    Builder().window.mainloop()
