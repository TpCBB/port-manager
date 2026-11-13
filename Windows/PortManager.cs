using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Management;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

class PortRecord
{
    public string Protocol, Address, State, Name, Path, Command;
    public int Port, Pid;
    public long StartTicks;
    public bool Matches(string query, string protocol)
    {
        if (protocol != "全部协议" && Protocol != protocol)
            return false;
        string text = String.Join(" ", new[] { Protocol, Port.ToString(), Address, State, Pid.ToString(), Name, Path, Command });
        return query.Length == 0 || text.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0;
    }

    public string Key
    {
        get
        {
            return Protocol + "|" + Address + "|" + Port + "|" + Pid;
        }
    }
}

static class PortScanner
{
    [DllImport("iphlpapi.dll", SetLastError = true)]
    static extern uint GetExtendedTcpTable(IntPtr table, ref int size, bool sort, int family, int kind, int reserved);
    [DllImport("iphlpapi.dll", SetLastError = true)]
    static extern uint GetExtendedUdpTable(IntPtr table, ref int size, bool sort, int family, int kind, int reserved);
    const int AF_INET = 2, AF_INET6 = 23;
    static int IntAt(IntPtr p, int n)
    {
        return Marshal.ReadInt32(p, n);
    }

    static int PortAt(IntPtr p, int n)
    {
        int v = IntAt(p, n);
        return ((v & 255) << 8) | ((v >> 8) & 255);
    }

    static string Addr(IntPtr p, int off, int family, int scopeOff)
    {
        byte[] a = new byte[family == AF_INET ? 4 : 16];
        Marshal.Copy(IntPtr.Add(p, off), a, 0, a.Length);
        if (family == AF_INET)
            return new IPAddress(a).ToString();
        return new IPAddress(a, (uint)IntAt(p, scopeOff)).ToString();
    }

    static void ReadTable(List<PortRecord> result, bool tcp, int family)
    {
        int size = 0;
        uint code = tcp ? GetExtendedTcpTable(IntPtr.Zero, ref size, false, family, 5, 0) : GetExtendedUdpTable(IntPtr.Zero, ref size, false, family, 1, 0);
        if (code != 122 && code != 0)
            throw new Exception("读取端口表失败：" + code);
        for (int attempt = 0; attempt < 4; attempt++)
        {
            IntPtr p = Marshal.AllocHGlobal(Math.Max(size, 4));
            try
            {
                int capacity = size;
                code = tcp ? GetExtendedTcpTable(p, ref size, false, family, 5, 0) : GetExtendedUdpTable(p, ref size, false, family, 1, 0);
                if (code == 122)
                    continue;
                if (code != 0)
                    throw new Exception("读取端口表失败：" + code);
                int count = IntAt(p, 0), len = tcp ? (family == AF_INET ? 24 : 56) : (family == AF_INET ? 12 : 28);
                if (count < 0 || (long)4 + (long)count * len > capacity)
                    throw new Exception("端口表格式异常");
                for (int i = 0; i < count; i++)
                {
                    int o = 4 + i * len, state = 0, remotePort = 0, pid, port, addrOff, scopeOff = 0;
                    if (tcp && family == AF_INET)
                    {
                        state = IntAt(p, o);
                        addrOff = o + 4;
                        port = PortAt(p, o + 8);
                        remotePort = PortAt(p, o + 16);
                        pid = IntAt(p, o + 20);
                    }
                    else if (tcp)
                    {
                        addrOff = o;
                        scopeOff = o + 16;
                        port = PortAt(p, o + 20);
                        remotePort = PortAt(p, o + 44);
                        state = IntAt(p, o + 48);
                        pid = IntAt(p, o + 52);
                    }
                    else if (family == AF_INET)
                    {
                        addrOff = o;
                        port = PortAt(p, o + 4);
                        pid = IntAt(p, o + 8);
                    }
                    else
                    {
                        addrOff = o;
                        scopeOff = o + 16;
                        port = PortAt(p, o + 20);
                        pid = IntAt(p, o + 24);
                    }

                    // Some Windows network providers report bound sockets with an unknown state (0).
                    // Keep these visible, but never label them as confirmed listeners.
                    if (tcp && state != 2 && !(state == 0 && remotePort == 0))
                        continue;
                    if (port == 0 || pid < 0)
                        continue;
                    result.Add(new PortRecord { Protocol = tcp ? "TCP" : "UDP", Address = Addr(p, addrOff, family, scopeOff), Port = port, Pid = pid, State = tcp ? (state == 2 ? "监听中" : "状态未知") : "已绑定" });
                }

                return;
            }
            finally
            {
                Marshal.FreeHGlobal(p);
            }
        }

        throw new Exception("端口变化过快，请重试");
    }

    public static List<PortRecord> Scan()
    {
        var result = new List<PortRecord>();
        ReadTable(result, true, AF_INET);
        ReadTable(result, true, AF_INET6);
        ReadTable(result, false, AF_INET);
        ReadTable(result, false, AF_INET6);
        var cache = new Dictionary<int, PortRecord>();
        foreach (var r in result)
        {
            PortRecord info;
            if (!cache.TryGetValue(r.Pid, out info))
            {
                info = new PortRecord();
                if (r.Pid == 0)
                    info.Name = "系统空闲进程";
                else if (r.Pid == 4)
                    info.Name = "System";
                else
                    try
                    {
                        using (var p = Process.GetProcessById(r.Pid))
                        {
                            info.Name = p.ProcessName;
                            try
                            {
                                info.StartTicks = p.StartTime.ToUniversalTime().Ticks;
                            }
                            catch
                            {
                            }

                            try
                            {
                                info.Path = p.MainModule.FileName;
                            }
                            catch
                            {
                            }
                        }
                    }
                    catch
                    {
                    }

                cache[r.Pid] = info;
            }

            r.Name = info.Name ?? "无法读取";
            r.Path = info.Path ?? "";
            r.StartTicks = info.StartTicks;
        }

        try
        {
            using (var query = new ManagementObjectSearcher("SELECT ProcessId,CommandLine FROM Win32_Process"))
            using (var list = query.Get())
            {
                foreach (ManagementObject item in list)
                {
                    using (item)
                    {
                        int id = Convert.ToInt32(item["ProcessId"]);
                        PortRecord info;
                        if (cache.TryGetValue(id, out info))
                            info.Command = Convert.ToString(item["CommandLine"]);
                    }
                }
            }
        }
        catch
        {
        }

        foreach (var r in result)
        {
            PortRecord info;
            if (cache.TryGetValue(r.Pid, out info))
                r.Command = info.Command ?? "";
        }

        return result;
    }

    public static Process Validate(PortRecord row)
    {
        if (row.Pid <= 4 || row.Pid == Process.GetCurrentProcess().Id)
            throw new Exception("不能结束系统进程或端口管家自身。");
        if (row.StartTicks == 0)
            throw new Exception("无法核实进程启动时间，已取消操作。请尝试以管理员身份运行。");
        Process p = Process.GetProcessById(row.Pid);
        try
        {
            IntPtr stableHandle = p.Handle;
            if (p.StartTime.ToUniversalTime().Ticks != row.StartTicks)
                throw new Exception("进程已经改变，请刷新后重试。");
            if (!Scan().Any(x => x.Key == row.Key && x.StartTicks == row.StartTicks))
                throw new Exception("端口归属已改变，请刷新后重试。");
            return p;
        }
        catch
        {
            p.Dispose();
            throw;
        }
    }
}

class MainForm : Form
{
    TextBox search, details;
    ComboBox protocol;
    DataGridView grid;
    Label status;
    Button refresh, graceful, force;
    NotifyIcon tray;
    System.Windows.Forms.Timer timer;
    bool loading, exiting;
    int detailsVersion;
    List<PortRecord> records = new List<PortRecord>();
    public MainForm()
    {
        Text = "端口管家 Windows 版";
        Width = 1170;
        Height = 720;
        MinimumSize = new Size(850, 550);
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Microsoft YaHei UI", 9F);
        BackColor = Color.White;
        Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        var top = new Panel
        {
            Dock = DockStyle.Top,
            Height = 112,
            BackColor = Color.FromArgb(245, 248, 252)
        };
        Controls.Add(top);
        top.Controls.Add(new Label { Text = "端口管家", Font = new Font("Microsoft YaHei UI", 17, FontStyle.Bold), AutoSize = true, Location = new Point(18, 8) });
        top.Controls.Add(new Label { Text = "查看端口和进程来源", AutoSize = true, ForeColor = Color.DimGray, Location = new Point(150, 20) });
        search = new TextBox
        {
            Location = new Point(18, 63),
            Width = 250
        };
        top.Controls.Add(search);
        search.TextChanged += (s, e) => ApplyFilter();
        protocol = new ComboBox
        {
            Location = new Point(280, 61),
            Width = 104,
            DropDownStyle = ComboBoxStyle.DropDownList
        };
        protocol.Items.AddRange(new object[] { "全部协议", "TCP", "UDP" });
        protocol.SelectedIndex = 0;
        top.Controls.Add(protocol);
        protocol.SelectedIndexChanged += (s, e) => ApplyFilter();
        refresh = new Button
        {
            Text = "刷新",
            Location = new Point(396, 57),
            Size = new Size(75, 32)
        };
        top.Controls.Add(refresh);
        refresh.Click += (s, e) => Reload();
        graceful = new Button
        {
            Text = "请求关闭",
            Location = new Point(480, 57),
            Size = new Size(90, 32)
        };
        top.Controls.Add(graceful);
        graceful.Click += (s, e) => EndProcess(false);
        force = new Button
        {
            Text = "强制结束",
            Location = new Point(580, 57),
            Size = new Size(90, 32)
        };
        top.Controls.Add(force);
        force.Click += (s, e) => EndProcess(true);
        status = new Label
        {
            Dock = DockStyle.Bottom,
            Height = 30,
            Padding = new Padding(12, 6, 0, 0),
            Text = "准备就绪"
        };
        Controls.Add(status);
        var split = new SplitContainer
        {
            Dock = DockStyle.Fill,
            Orientation = Orientation.Horizontal,
            SplitterDistance = 370,
            Panel2MinSize = 110,
            BackColor = Color.FromArgb(236, 239, 243)
        };
        Controls.Add(split);
        split.BringToFront();
        grid = new DataGridView
        {
            Dock = DockStyle.Fill,
            ReadOnly = true,
            AllowUserToAddRows = false,
            AllowUserToDeleteRows = false,
            AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill,
            SelectionMode = DataGridViewSelectionMode.FullRowSelect,
            MultiSelect = false,
            RowHeadersVisible = false,
            BackgroundColor = Color.White,
            BorderStyle = BorderStyle.None
        };
        split.Panel1.Controls.Add(grid);
        grid.Columns.Add("Protocol", "协议");
        grid.Columns.Add("Port", "端口");
        grid.Columns.Add("Address", "本地地址");
        grid.Columns.Add("State", "状态");
        grid.Columns.Add("Pid", "PID");
        grid.Columns.Add("Name", "进程");
        grid.Columns.Add("Path", "程序路径");
        int[] widths =
        {
            48,
            48,
            105,
            67,
            48,
            90,
            200
        };
        for (int i = 0; i < widths.Length; i++)
            grid.Columns[i].FillWeight = widths[i];
        grid.SelectionChanged += (s, e) => ShowDetails();
        details = new TextBox
        {
            Dock = DockStyle.Fill,
            Multiline = true,
            ReadOnly = true,
            ScrollBars = ScrollBars.Vertical,
            BorderStyle = BorderStyle.None,
            BackColor = Color.FromArgb(250, 251, 253),
            Font = new Font("Microsoft YaHei UI", 9F),
            Text = "选择一个端口查看进程详情"
        };
        split.Panel2.Controls.Add(details);
        var menu = new ContextMenuStrip();
        menu.Items.Add("打开端口管家", null, (s, e) => ShowWindow());
        menu.Items.Add("刷新", null, (s, e) => Reload());
        menu.Items.Add("退出", null, (s, e) => ExitApp());
        tray = new NotifyIcon
        {
            Text = "端口管家",
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath),
            ContextMenuStrip = menu,
            Visible = true
        };
        tray.DoubleClick += (s, e) => ShowWindow();
        FormClosing += (s, e) =>
        {
            if (!exiting && e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true;
                Hide();
                tray.ShowBalloonTip(1500, "端口管家", "程序仍在系统托盘运行，可右键退出。", ToolTipIcon.Info);
            }
            else
            {
                tray.Visible = false;
                tray.Dispose();
            }
        };
        timer = new System.Windows.Forms.Timer
        {
            Interval = 10000
        };
        timer.Tick += (s, e) => Reload();
        timer.Start();
        Shown += (s, e) => Reload();
    }

    void ShowWindow()
    {
        Show();
        WindowState = FormWindowState.Normal;
        Activate();
    }

    void ExitApp()
    {
        exiting = true;
        Close();
    }

    void Reload()
    {
        if (loading)
            return;
        loading = true;
        refresh.Enabled = false;
        status.Text = "正在扫描端口…";
        ThreadPool.QueueUserWorkItem(_ =>
        {
            try
            {
                var data = PortScanner.Scan();
                if (IsDisposed)
                    return;
                BeginInvoke((Action)(() =>
                {
                    records = data;
                    loading = false;
                    refresh.Enabled = true;
                    ApplyFilter();
                }));
            }
            catch (Exception ex)
            {
                if (IsDisposed)
                    return;
                try
                {
                    BeginInvoke((Action)(() =>
                    {
                        loading = false;
                        refresh.Enabled = true;
                        status.Text = "扫描失败：" + ex.Message;
                    }));
                }
                catch
                {
                }
            }
        });
    }

    void ApplyFilter()
    {
        if (loading)
            return;
        string current = Selected() == null ? null : Selected().Key;
        string q = search.Text.Trim();
        string filter = protocol.SelectedItem.ToString();
        grid.SuspendLayout();
        grid.Rows.Clear();
        int selected = -1;
        foreach (var r in records.OrderBy(x => x.Port).ThenBy(x => x.Pid))
        {
            if (!r.Matches(q, filter))
                continue;
            int i = grid.Rows.Add(r.Protocol, r.Port, r.Address, r.State, r.Pid, r.Name, r.Path);
            grid.Rows[i].Tag = r;
            if (r.Key == current)
                selected = i;
        }

        if (selected >= 0)
        {
            grid.ClearSelection();
            grid.Rows[selected].Selected = true;
            grid.CurrentCell = grid.Rows[selected].Cells[0];
        }

        grid.ResumeLayout();
        status.Text = String.Format("显示 {0} 条 · 每 10 秒自动刷新 · {1:HH:mm:ss}", grid.Rows.Count, DateTime.Now);
        ShowDetails();
    }

    PortRecord Selected()
    {
        return grid.SelectedRows.Count > 0 ? grid.SelectedRows[0].Tag as PortRecord : null;
    }

    void ShowDetails()
    {
        var row = Selected();
        int version = ++detailsVersion;
        if (row == null)
        {
            details.Text = "选择一个端口查看进程详情";
            return;
        }

        details.Text = String.Format("端口：{0} {1}:{2}    状态：{3}\r\n进程：{4}    PID：{5}\r\n路径：{6}\r\n正在读取启动命令和父进程…", row.Protocol, row.Address, row.Port, row.State, row.Name, row.Pid, row.Path.Length > 0 ? row.Path : "不可读取");
        ThreadPool.QueueUserWorkItem(_ =>
        {
            string cmd = "不可读取", parent = "不可读取", services = "无或不可读取";
            try
            {
                using (var query = new ManagementObjectSearcher("SELECT CommandLine, ParentProcessId FROM Win32_Process WHERE ProcessId=" + row.Pid))
                using (var result = query.Get())
                {
                    foreach (ManagementObject item in result)
                    {
                        using (item)
                        {
                            cmd = Convert.ToString(item["CommandLine"]);
                            int p = Convert.ToInt32(item["ParentProcessId"]);
                            parent = p.ToString();
                            try
                            {
                                using (var pp = Process.GetProcessById(p))
                                    parent += " (" + pp.ProcessName + ")";
                            }
                            catch
                            {
                            }
                        }
                    }
                }
            }
            catch
            {
            }

            try
            {
                var names = new List<string>();
                using (var sq = new ManagementObjectSearcher("SELECT Name,State,StartMode FROM Win32_Service WHERE ProcessId=" + row.Pid))
                using (var sl = sq.Get())
                {
                    foreach (ManagementObject si in sl)
                    {
                        using (si)
                        {
                            names.Add(Convert.ToString(si["Name"]) + " (" + Convert.ToString(si["State"]) + ", " + Convert.ToString(si["StartMode"]) + ")");
                        }
                    }
                }

                if (names.Count > 0)
                    services = String.Join("；", names.ToArray());
            }
            catch
            {
            }

            if (IsDisposed)
                return;
            try
            {
                BeginInvoke((Action)(() =>
                {
                    if (version != detailsVersion)
                        return;
                    details.Text = String.Format("端口：{0} {1}:{2}    状态：{3}\r\n进程：{4}    PID：{5}\r\n路径：{6}\r\n启动命令：{7}\r\n父进程：{8}\r\n启动时间：{9}\r\nWindows 服务：{10}", row.Protocol, row.Address, row.Port, row.State, row.Name, row.Pid, String.IsNullOrEmpty(row.Path) ? "不可读取" : row.Path, String.IsNullOrEmpty(cmd) ? "不可读取" : cmd, parent, row.StartTicks == 0 ? "不可读取" : new DateTime(row.StartTicks, DateTimeKind.Utc).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss"), services);
                }));
            }
            catch
            {
            }
        });
    }

    void EndProcess(bool forced)
    {
        var row = Selected();
        if (row == null)
        {
            MessageBox.Show("请先选中端口。");
            return;
        }

        string action = forced ? "强制结束" : "请求关闭";
        string ports = String.Join("、", records.Where(x => x.Pid == row.Pid).Select(x => x.Protocol + ":" + x.Port).Distinct().ToArray());
        if (MessageBox.Show(String.Format("{0}进程 {1}（PID {2}）？\n关联端口：{3}\n未保存的内容可能丢失。", action, row.Name, row.Pid, ports), "确认" + action, MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes)
            return;
        try
        {
            using (var p = PortScanner.Validate(row))
            {
                if (forced)
                    p.Kill();
                else if (!p.CloseMainWindow())
                {
                    MessageBox.Show("这个进程没有可关闭的主窗口，无法请求正常关闭。若确定需要，可选择“强制结束”。", "端口管家");
                    return;
                }
            }

            Reload();
        }
        catch (Exception ex)
        {
            MessageBox.Show("操作失败：" + ex.Message + "\n权限不足时可尝试以管理员身份运行。", "端口管家", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            Reload();
        }
    }
}

static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        if (args.Length == 2 && args[0] == "--self-test")
        {
            SelfTest(args[1]);
            return;
        }

        if (args.Length == 2 && args[0] == "--test-child")
        {
            var l = new TcpListener(IPAddress.Loopback, 0);
            l.Start();
            File.WriteAllText(args[1], ((IPEndPoint)l.LocalEndpoint).Port.ToString());
            Thread.Sleep(30000);
            l.Stop();
            return;
        }

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new MainForm());
    }

    static void SelfTest(string path)
    {
        var log = new List<string>();
        TcpListener tcp = null;
        UdpClient udp = null;
        Process child = null;
        string flag = path + ".child";
        try
        {
            tcp = new TcpListener(IPAddress.Loopback, 0);
            tcp.Start();
            udp = new UdpClient(new IPEndPoint(IPAddress.Loopback, 0));
            int tp = ((IPEndPoint)tcp.LocalEndpoint).Port, up = ((IPEndPoint)udp.Client.LocalEndPoint).Port, pid = Process.GetCurrentProcess().Id;
            var rows = PortScanner.Scan();
            var tr = rows.FirstOrDefault(x => x.Port == tp && x.Pid == pid && x.Protocol == "TCP");
            var ur = rows.FirstOrDefault(x => x.Port == up && x.Pid == pid && x.Protocol == "UDP");
            log.Add("tcp=" + (tr != null) + " state=" + (tr == null ? "missing" : tr.State) + " udp=" + (ur != null) + " count=" + rows.Count);
            if (tr == null || ur == null)
                throw new Exception("未识别当前进程的 TCP 或 UDP 端口");
            if (!tr.Matches(tp.ToString(), "TCP") || !tr.Matches(pid.ToString(), "全部协议") ||
                tr.Matches(tp.ToString(), "UDP") || tr.Matches("port-that-does-not-exist", "全部协议"))
                throw new Exception("端口搜索或协议筛选失败");
            log.Add("search_and_protocol_filter=true");
            if (Socket.OSSupportsIPv6)
            {
                TcpListener t6 = null;
                UdpClient u6 = null;
                try
                {
                    t6 = new TcpListener(IPAddress.IPv6Loopback, 0);
                    t6.Start();
                    u6 = new UdpClient(new IPEndPoint(IPAddress.IPv6Loopback, 0));
                    int t6p = ((IPEndPoint)t6.LocalEndpoint).Port, u6p = ((IPEndPoint)u6.Client.LocalEndPoint).Port;
                    var r6 = PortScanner.Scan();
                    bool t6ok = r6.Any(x => x.Protocol == "TCP" && x.Pid == pid && x.Port == t6p && x.Address.Contains(":")), u6ok = r6.Any(x => x.Protocol == "UDP" && x.Pid == pid && x.Port == u6p && x.Address.Contains(":"));
                    log.Add("tcp6=" + t6ok + " udp6=" + u6ok);
                    if (!t6ok || !u6ok)
                        throw new Exception("未识别 IPv6 监听端口");
                }
                finally
                {
                    if (t6 != null)
                        t6.Stop();
                    if (u6 != null)
                        u6.Close();
                }
            }

            if (File.Exists(flag))
                File.Delete(flag);
            child = Process.Start(new ProcessStartInfo(Application.ExecutablePath, "--test-child \"" + flag + "\"") { UseShellExecute = false, CreateNoWindow = true });
            for (int i = 0; i < 50 && !File.Exists(flag); i++)
                Thread.Sleep(100);
            if (!File.Exists(flag))
                throw new Exception("测试进程启动超时");
            int cp = 0;
            for (int i = 0; i < 50 && cp == 0; i++)
            {
                try { Int32.TryParse(File.ReadAllText(flag), out cp); }
                catch (IOException) { }
                if (cp == 0) Thread.Sleep(100);
            }
            if (cp == 0) throw new Exception("测试进程未写入有效端口");
            PortRecord cr = null;
            for (int i = 0; i < 20 && cr == null; i++)
            {
                cr = PortScanner.Scan().FirstOrDefault(x => x.Pid == child.Id && x.Port == cp && x.Protocol == "TCP");
                if (cr == null)
                    Thread.Sleep(100);
            }

            if (cr == null)
                throw new Exception("未识别测试子进程端口");
            long oldTicks = cr.StartTicks;
            cr.StartTicks = oldTicks + 1;
            bool staleRejected = false;
            try
            {
                using (var invalid = PortScanner.Validate(cr))
                {
                }
            }
            catch
            {
                staleRejected = true;
            }

            cr.StartTicks = oldTicks;
            if (!staleRejected)
                throw new Exception("错误的进程身份未被拒绝");
            log.Add("stale_identity_rejected=true");
            int originalPort = cr.Port;
            cr.Port = 0;
            bool changedPortRejected = false;
            try { using (var invalid = PortScanner.Validate(cr)) { } }
            catch { changedPortRejected = true; }
            cr.Port = originalPort;
            if (!changedPortRejected) throw new Exception("已改变的端口归属未被拒绝");
            log.Add("changed_port_rejected=true");
            using (var checkedProcess = PortScanner.Validate(cr))
            {
                checkedProcess.Kill();
            }

            if (!child.WaitForExit(5000))
                throw new Exception("测试子进程没有退出");
            log.Add("child_scan_and_validated_kill=true");
            log.Add("PASS");
        }
        catch (Exception ex)
        {
            log.Add("FAIL " + ex);
            Environment.ExitCode = 1;
        }
        finally
        {
            if (tcp != null)
                tcp.Stop();
            if (udp != null)
                udp.Close();
            if (child != null)
            {
                try
                {
                    if (!child.HasExited)
                        child.Kill();
                }
                catch
                {
                }

                child.Dispose();
            }

            try
            {
                if (File.Exists(flag))
                    File.Delete(flag);
            }
            catch
            {
            }

            File.WriteAllLines(path, log.ToArray(), Encoding.UTF8);
        }
    }
}
