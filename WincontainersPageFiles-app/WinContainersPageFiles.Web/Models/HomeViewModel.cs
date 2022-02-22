using System.Collections.Generic;

namespace WinContainersPageFiles.Web.Models
{
    public class HomeViewModel
    {
        public bool Is64BitOperatingSystem => System.Environment.Is64BitOperatingSystem;

        public List<PageFileUsageViewModel> PageFileUsageViewModels { get; set; }
        public OsViewModel OsViewModel { get; set; }
        public ProcessViewModel ProcessViewModel { get; set; }
    }
}