# Exploring Windows Containers: Page Files

## And down the rabbit hole we go

A few weeks ago I received an excellent question from a community member, which sent me down the fascinating rabbit hole of Windows containers once again. The question, and while I’m paraphrasing, went something along these lines:

> “Could you share some information on how page files are allocated in a Windows Server container setting?"

I honestly did not know whether page files would behave differently in a containerized setting, though I suspected that they wouldn’t. I decided to write down and share my findings.

Feel free to read the [full blog post](https://thomasvanlaere.com/posts/2022/02/exploring-windows-containers-page-files/)!

## The test setup

As I was figuring things out, I used a few Azure services to perform my tests. If you'd like to try some of them out for yourself, feel free to do so. I created a Bicep template that provisions a bunch of resources that should make it pretty straightforward to stress test a container and host's memory and associated page file.

I used some platform-as-a-service offerings:

- __Azure Container Registry__ + __Tasks__
  - Will automatically pull code and build a Windows container image.
  - Eventually, the built image is pushed into the registry.
- __Azure Container Instance__
  - Used to run the built Windows container image.
- __Azure App Service Plan P1V3__
  - runs __Hyper-V isolated__ Windows Containers.
- __Azure App Services__
  - Used to run the built Windows container image.
  - Memory limit for a single container has been modified to use four-ish GBs of the eight that are available.

And some infrastructure-as-a-service offerings:

- Two __Azure Virtual Machines__
  - One __Standard_D4s_v3__ and one __Standard_E4-2s_v4__.
  - Visual Studio 2022 latest with Windows Server 2022.
- Two premium __Managed Disks__
  - P10/128 Gb disks
- Two custom script extensions
  - A PowerShell script that installs Docker and the Containers and Hyper-V Windows features.
    - This becomes [deprecated](https://docs.microsoft.com/en-us/virtualization/windowscontainers/quick-start/set-up-environment?tabs=Windows-Server#install-docker) by September 2022.
- __Virtual Network__
  - Holds the two VMs.
- Two __public IP addresses__
  - Since we need to connect to it without much hassle.
- __Network Security Group__
  - Only allows RDP from your IP to the VMs.


[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FThomVanL%2Fblog-2022-02-exploring-windows-containers-page-files%2Fmain%2F%2Fazuredeploy.json)

[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FThomVanL%2Fblog-2022-02-exploring-windows-containers-page-files%2Fmain%2F%2Fazuredeploy.json)
