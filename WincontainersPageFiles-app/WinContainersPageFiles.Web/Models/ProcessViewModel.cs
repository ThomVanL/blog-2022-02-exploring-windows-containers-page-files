namespace WinContainersPageFiles.Web.Models
{
    public class ProcessViewModel
    {
        public double PrivateMemorySize64 { get; set; }
        public double PeakPagedMemorySize64 { get; set; }
        public double PagedMemorySize64 { get; set; }

    }
}