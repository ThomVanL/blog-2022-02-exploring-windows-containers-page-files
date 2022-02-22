using System;
using System.ComponentModel.DataAnnotations;

namespace WinContainersPageFiles.Web.Models
{
    public class AllocateViewModel
    {
        [Display(Name = "Amount in bytes")]
        [Range(1, int.MaxValue)]
        public int Amount { get; set; }

        [Display(Name = "Type")]
        [RegularExpression("Physical|VirtualCommitDemand|VirtualCommitAndRamDemand|CreateFileMapping")]
        public string Type { get; set; }
    }
}