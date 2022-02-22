using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using System.Management;
using WinContainersPageFiles.Web.Models;
using System.Runtime.InteropServices;
using System.Diagnostics;
using WinContainersPageFiles.Web.Utils;

namespace WinContainersPageFiles.Web.Controllers
{
    public class HomeController : Controller
    {
        private static readonly List<byte[]> allocations = new List<byte[]>();

        public ActionResult Index()
        {
            HomeViewModel homeVm = new HomeViewModel
            {
                OsViewModel = new OsViewModel(),
                ProcessViewModel = new ProcessViewModel()
            };

            Process currentProcess = Process.GetCurrentProcess();
            homeVm.ProcessViewModel.PeakPagedMemorySize64 = currentProcess.PeakPagedMemorySize64 / Math.Pow(1024, 2);
            homeVm.ProcessViewModel.PagedMemorySize64 = currentProcess.PagedMemorySize64 / Math.Pow(1024, 2);
            homeVm.ProcessViewModel.PrivateMemorySize64 = currentProcess.PrivateMemorySize64 / Math.Pow(1024, 2);


            ManagementScope scope = new ManagementScope("\\\\.\\root\\cimv2");
            scope.Connect();

            ObjectQuery osQuery = new ObjectQuery("SELECT * FROM Win32_OperatingSystem");
            using (ManagementObjectSearcher osObjectSearcher = new ManagementObjectSearcher(scope, osQuery))
            {
                ManagementObjectCollection osManagementObjects = osObjectSearcher.Get();

                foreach (ManagementObject osManagementObject in osManagementObjects)
                {
                    homeVm.OsViewModel.FreePhysicalMemory = ((ulong)osManagementObject["FreePhysicalMemory"] / 1024D);
                    homeVm.OsViewModel.FreeVirtualMemory = ((ulong)osManagementObject["FreeVirtualMemory"] / 1024D);
                    homeVm.OsViewModel.TotalVisibleMemorySize = ((ulong)osManagementObject["TotalVisibleMemorySize"] / 1024D);
                    homeVm.OsViewModel.TotalVirtualMemorySize = ((ulong)osManagementObject["TotalVirtualMemorySize"] / 1024D);
                }
            }



            ObjectQuery pageFilesQuery = new ObjectQuery("SELECT * FROM Win32_PageFileusage");
            using (ManagementObjectSearcher pageFilesObjectSearcher = new ManagementObjectSearcher(scope, pageFilesQuery))
            {
                ManagementObjectCollection pageFilesQueryCollection = pageFilesObjectSearcher.Get();
                List<PageFileUsageViewModel> pageFileUsageViewModels = new List<PageFileUsageViewModel>();

                foreach (ManagementObject pageFileUsage in pageFilesQueryCollection)
                {
                    pageFileUsageViewModels.Add(new PageFileUsageViewModel
                    {
                        CurrentUsage = (uint)pageFileUsage["CurrentUsage"],
                        AllocatedBaseSize = (uint)pageFileUsage["AllocatedBaseSize"],
                        PeakUsage = (uint)pageFileUsage["PeakUsage"],
                        Path = pageFileUsage.Path.ToString()
                    });
                }

                homeVm.PageFileUsageViewModels = pageFileUsageViewModels;
                return View(homeVm);

            }
        }

        public ActionResult Allocate()
        {
            return View(new AllocateViewModel { Amount = 2136746229 });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Allocate(AllocateViewModel vm)
        {
            if (!ModelState.IsValid) return View(vm);

            try
            {
                IntPtr hglobal;

                switch (vm.Type)
                {
                    case "Physical":
                        hglobal = Marshal.AllocHGlobal(vm.Amount);
                        MemUtils.FillMemoryWithZeroes(hglobal, (uint)vm.Amount);
                        break;
                    case "VirtualCommitDemand":
                        hglobal = MemUtils.VirtualAlloc(IntPtr.Zero, vm.Amount, 0x00001000 | 0x00002000, 0x40);
                        break;
                    case "VirtualCommitAndRamDemand":
                        hglobal = MemUtils.VirtualAlloc(IntPtr.Zero, vm.Amount, 0x00001000 | 0x00002000, 0x40);
                        MemUtils.FillMemoryWithZeroes(hglobal, (uint)vm.Amount);
                        break;
                    case "CreateFileMapping":
                        //PAGE_READWRITE
                        IntPtr hMapFile = MemUtils.CreateFileMapping(new IntPtr(-1), IntPtr.Zero, 0x04, 0, (uint)(vm.Amount), null);
                        if (hMapFile == IntPtr.Zero) { throw new Exception(message: $"CreateFileMapping - System error code:{Marshal.GetLastWin32Error()}"); }

                        //FILE_MAP_WRITE
                        IntPtr pView = MemUtils.MapViewOfFile(hMapFile, 0x02, 0, 0, vm.Amount);
                        if (pView == IntPtr.Zero) { throw new Exception(message: $"MapViewOfFile - System error code:{Marshal.GetLastWin32Error()}"); }

                        MemUtils.FillMemoryWithZeroes(pView, (uint)vm.Amount);
                        MemUtils.UnmapViewOfFile(pView);
                        break;
                    default:
                        break;
                }

            }
            catch (Exception ex)
            {
                ModelState.AddModelError("Amount", ex.Message);
                return View(vm);
            }
            return RedirectToAction("Index");
        }

    }
}