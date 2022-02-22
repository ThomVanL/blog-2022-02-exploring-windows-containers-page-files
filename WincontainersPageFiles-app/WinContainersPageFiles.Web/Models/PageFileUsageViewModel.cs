using System.Linq;
using System.Web;

namespace WinContainersPageFiles.Web.Models
{
    public class PageFileUsageViewModel
    {
        public uint CurrentUsage { get; set; }
        public uint AllocatedBaseSize { get; set; }
        public uint PeakUsage { get; set; }
        public string Path { get; set; }
    }
}