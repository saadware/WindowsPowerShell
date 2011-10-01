@{
	ModuleVersion="0.0.0.1"
	Description="A Wrapper for Microsoft's SQL Server PowerShell Extensions Snapins"
	Author="Scott Saad"
	Copyright="1997 Efficient Workflow Solutions, LLC"
	CompanyName="Efficient Workflow Solutions, LLC"
	CLRVersion="2.0"
	FormatsToProcess="SQLProvider.Format.ps1xml"
	Guid="94cf5405-1d10-4165-925b-4f31658ab530"
	NestedModules="Microsoft.SqlServer.Management.PSSnapins.dll","Microsoft.SqlServer.Management.PSProvider.dll"
	RequiredAssemblies="Microsoft.SqlServer.Smo","Microsoft.SqlServer.Dmf","Microsoft.SqlServer.SqlWmiManagement","Microsoft.SqlServer.ConnectionInfo","Microsoft.SqlServer.SmoExtended","Microsoft.SqlServer.Management.RegisteredServers","Microsoft.SqlServer.Management.Sdk.Sfc","Microsoft.SqlServer.SqlEnum","Microsoft.SqlServer.RegSvrEnum","Microsoft.SqlServer.WmiEnum","Microsoft.SqlServer.ServiceBrokerEnum","Microsoft.SqlServer.ConnectionInfoExtended","Microsoft.SqlServer.Management.Collector","Microsoft.SqlServer.Management.CollectorEnum"
	TypesToProcess="SQLProvider.Types.ps1xml"
	ScriptsToProcess="MsSql.ps1"
}
