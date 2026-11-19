using System;
using System.Linq;
using System.Net;
using System.Security.Cryptography;
using System.IO;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

internal static class ReleaseUpdates
{
    public sealed class Asset { public string name { get; set; } public string state { get; set; } public string digest { get; set; } public long size { get; set; } }
    public sealed class Release
    {
        public string tag_name { get; set; }
        public bool? draft { get; set; }
        public Asset[] assets { get; set; }
    }

    internal sealed class Package
    {
        public string Version, Name, Hash;
        public long Size;
    }

    internal static Package Newest(Release[] releases, string installed)
    {
        Version best = Version.Parse(installed);
        Package result = null;
        foreach (Release release in releases)
        {
            if (release == null || release.draft != false || release.assets == null ||
                String.IsNullOrEmpty(release.tag_name) || release.tag_name[0] != 'v') continue;
            string candidate = release.tag_name.Substring(1);
            Version version;
            if (!Version.TryParse(candidate, out version) || version.Build < 0 || version.Revision >= 0 ||
                candidate.Any(c => c != '.' && (c < '0' || c > '9')) || version <= best) continue;
            var asset = release.assets.FirstOrDefault(a => a != null && a.state == "uploaded" && a.name == "PortManager-" + candidate + "-win-x64.exe");
            if (asset == null || asset.size <= 0 || asset.size > 256 * 1024 * 1024 || asset.digest == null ||
                !System.Text.RegularExpressions.Regex.IsMatch(asset.digest, @"\Asha256:[a-f0-9]{64}\z")) continue;
            best = version;
            result = new Package { Version = candidate, Name = asset.name, Size = asset.size, Hash = asset.digest.Substring(7) };
        }
        return result;
    }

    internal static Release[] Decode(string body)
    {
        return new JavaScriptSerializer().Deserialize<Release[]>(body);
    }

    internal static Task<Package> Check(string installed)
    {
        // The framework HTTP API is synchronous; never run it on the tray's UI thread.
        return Task.Run(() => {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            Package best = null;
            for (int page = 1; ; page++)
            {
                var request = (HttpWebRequest)WebRequest.Create("https://api.github.com/repos/TpCBB/port-manager/releases?per_page=20&page=" + page);
                request.UserAgent = "PortManager";
                request.Accept = "application/vnd.github+json";
                request.Timeout = request.ReadWriteTimeout = 10000;
                using (var response = (HttpWebResponse)request.GetResponse())
                using (var reader = new StreamReader(response.GetResponseStream()))
                {
                    var releases = Decode(reader.ReadToEnd());
                    best = Newest(releases, best == null ? installed : best.Version) ?? best;
                    if (releases.Length < 20) return best;
                }
            }
        });
    }
    // Keep the partial file private to this transfer. Only publish the EXE after verification.
    internal static string SaveVerified(Package package, Stream input, string parent, Action<int> progress)
    {
        string dir = Path.Combine(parent, Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(dir);
        string partial = Path.Combine(dir, "download.part"), final = Path.Combine(dir, package.Name);
        try
        {
            using (var sha = SHA256.Create())
            using (var output = new FileStream(partial, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                byte[] buffer = new byte[65536];
                long count = 0;
                int n, last = -1;
                while ((n = input.Read(buffer, 0, buffer.Length)) > 0)
                {
                    count += n;
                    if (count > package.Size) throw new InvalidDataException();
                    output.Write(buffer, 0, n);
                    sha.TransformBlock(buffer, 0, n, buffer, 0);
                    int percent = (int)(count * 100 / package.Size);
                    if (percent != last) { last = percent; progress(percent); }
                }
                sha.TransformFinalBlock(buffer, 0, 0);
                if (count != package.Size || !String.Equals(BitConverter.ToString(sha.Hash).Replace("-", ""), package.Hash, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException();
            }
            // Preserve Windows' internet-origin warning when the user later runs the EXE.
            if (!MarkInternetFile(partial)) throw new IOException("Cannot mark downloaded file");
            File.Move(partial, final);
            return final;
        }
        catch { File.Delete(partial); Directory.Delete(dir); throw; }
    }

    // .NET Framework's FileStream path validation does not support NTFS stream names.
    [System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, SetLastError = true)]
    static extern Microsoft.Win32.SafeHandles.SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr security, uint disposition, uint attributes, IntPtr template);
    static bool MarkInternetFile(string path)
    {
        using (var handle = CreateFile(path + ":Zone.Identifier", 0x40000000, 0, IntPtr.Zero, 2, 0, IntPtr.Zero))
        {
            if (handle.IsInvalid) return false;
            using (var stream = new FileStream(handle, FileAccess.Write))
            {
                byte[] mark = System.Text.Encoding.ASCII.GetBytes("[ZoneTransfer]\r\nZoneId=3\r\n");
                stream.Write(mark, 0, mark.Length);
            }
        }
        return true;
    }

    internal static Task<string> Download(Package package, IProgress<int> progress)
    {
        return Task.Run(() => {
            string url = "https://github.com/TpCBB/port-manager/releases/download/v" + package.Version + "/" + package.Name;
            var request = (HttpWebRequest)WebRequest.Create(url);
            request.UserAgent = "PortManager";
            request.Timeout = request.ReadWriteTimeout = 30000;
            using (var response = (HttpWebResponse)request.GetResponse())
            using (var input = response.GetResponseStream())
            {
                if (response.StatusCode != HttpStatusCode.OK || response.ResponseUri.Scheme != "https") throw new IOException();
                string parent = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PortManager", "Downloads");
                return SaveVerified(package, input, parent, progress.Report);
            }
        });
    }

}
