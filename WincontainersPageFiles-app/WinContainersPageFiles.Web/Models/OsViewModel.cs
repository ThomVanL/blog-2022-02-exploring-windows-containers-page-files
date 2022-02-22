namespace WinContainersPageFiles.Web.Models
{
    public class OsViewModel
    {
        public double TotalVisibleMemorySize { get; set; }
        public double FreePhysicalMemory { get; set; }
        public double TotalVirtualMemorySize { get; set; }
        public double FreeVirtualMemory { get; set; }
    }
}