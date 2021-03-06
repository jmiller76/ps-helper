function Disable-Access {
    <#
    .SYNOPSIS
        Deny student group permission to a file.
    .DESCRIPTION
        Add an NTFS Deny ACL to a given file for students to block their access.
        A deny rule supercedes any allow rule.
    .EXAMPLE
        PS C:\> \\<server\<share>\<Path> | Disable-Access | Convertto-html | Out-File "Report.html"
        Generate a report that lists the files students have been blocked from using.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Position = 0)]
        [String[]]
        $Path
        , # AD identity
        [Parameter(ValueFromPipelineByPropertyName,
                   Position = 1)]
        [string]
        $Identity = 'AllStudents'
    )
    Begin {
        $Deny = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Identity, 'FullControl', 'Deny'
    }
    Process {
        $Path | Get-Acl | foreach-object {
            $psitem.SetAccessRule($Deny)
            try { $psitem | Set-acl }
            catch {
                Throw "Failed to set permission: $($psitem.path)"
            }
            Get-Item $psitem.Path | Write-Output
        }
    }
}

function Enable-Access {
    <#
    .SYNOPSIS
        Remove "Deny" permission added by "Deny-Access"
    .DESCRIPTION
        Remove the NTFS Deny ACL for a given item for students access.
        Does not test that users get access permission. See Add-Access
    .EXAMPLE
        PS C:\> \\<server\<share>\<Path> | Enable-Access | Convertto-html | Out-File "Report.html"
        Generate a report that lists the item students have been blocked from using.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Position = 0)]
        [String[]]
        $Path
        , # AD identity
        [Parameter(ValueFromPipelineByPropertyName,
                   Position = 1)]
        [string]
        $Identity = 'AllStudents'
    )
    Begin {
        $Rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Identity, 'FullControl', 'Deny'
    }
    Process {
        $Path | Get-Acl | foreach-object {
            $psitem.RemoveAccessRule($Rule) > $null
            try { $psitem | Set-acl }
            catch {
                Throw "Failed remove Deny permission: $($psitem.path)"
            }
            Get-Item $psitem.Path | Write-Output
        }
    }
    End {
        Write-Warning "Enable-StudentAccess will remove 'Deny' permission set by Disable-StudentAccess. See Add-Access"
    }
}

function Add-Access {
    <#
    .SYNOPSIS
        Add "Allow" permission to target path.
    .DESCRIPTION
        Add the NTFS Allow ACL for a given item for students access.
        Any deny rule will supercede this. See Enable-Access.
    .EXAMPLE
        Add-Access .\en-US\
        By default allow students to read permission to the folder
    .EXAMPLE
        Add-Access .\en-US\ -Identity '2016 Students'
        Specify the Active Directory identiy name to set access for;

            Directory: N:\Documents\src\ps-helper


        Mode                LastWriteTime         Length Name
        ----                -------------         ------ ----
        d-----       19/10/2016     15:33                en-US
    .EXAMPLE
        PS C:\> \\<server\<share>\<Path> | Add-Access | Convertto-html | Out-File "Report.html"
        Generate a report that lists the items students have been allowed to aceess.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   Position = 0
                   )]
        [String[]]
        $Path
        , # AD identity to grant access
        [Parameter(ValueFromPipelineByPropertyName,
                   Position = 1)]
        [string]
        $Identity = 'AllStudents'
        , # keyword access permission levels
        [ValidateSet('FullControl','Modify','ReadAndExecute')]
        [string]
        $Access = 'ReadAndExecute'
        , # Sets the Applies to contition for child items
        [ValidateSet('All','ThisFolder')]
        [string]
        $Inherit
    )
    Begin {
        switch ($inherit) {
            'ThisFolder' { $Inherritance = @('ObjectInherit') }
            Default { $Inherritance = @('ContainerInherit', 'ObjectInherit') }
        }
        $FolderRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Identity, $Access, $Inherritance, 'None', 'Allow'
        $FileRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Identity, $Access, 'Allow'
    }
    Process {
        $Path | Get-Acl | foreach-object {
            if ( (Get-Item $Path) -is [System.IO.DirectoryInfo] ){
                $psitem.SetAccessRule($FolderRule)
            } else {
                $psitem.SetAccessRule($FileRule)
            }
            try { $psitem | Set-acl }
            catch {
                Throw "Failed to add permission: $($psitem.path)"
            }
            Get-Item $psitem.Path | Write-Output
        }
    }
}

function Remove-Access {
    <#
    .SYNOPSIS
        Remove "Allow" permission added by "Add-StudentAccess"
    .DESCRIPTION
        Remove the NTFS Allow ACL for a given item for students access.
    .EXAMPLE
        PS C:\> \\<server\<share>\<Path> | Remove-StudentAccess | Convertto-html | Out-File "Report.html"
        Generate a report that lists the items students have been blocked from using.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName,
                   Position = 0)]
        [String[]]
        $Path
        , # AD identity to remove access
        [Parameter(ValueFromPipelineByPropertyName,
                   Position = 1)]
        [string]
        $Identity = 'AllStudents'
    )
    Begin {
    }
    Process {
        $Path | Get-Acl | foreach-object {
            $Rule = $psitem.Access | Where-Object { ($_.IdentityReference -eq $Identity) -and ($_.AccessControlType -eq  'Allow')}
            $psitem.RemoveAccessRule($Rule) > $null
            try { $psitem | Set-acl }
            catch {
                Throw "Failed to remove permission: $($psitem.path)"
            }
            Get-Item $psitem.Path | Write-Output
        }
    }
}

Register-ArgumentCompleter -CommandName 'Add-Access','Remove-Access','Enable-Access','Disable-Access' -ParameterName 'Identity' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
    [System.Collections.ArrayList]$preset = @(
        'AllStudents'
        'AllCAStudents'
        'AllStaff'
        'Office'
        "'Site Management'"
        "'Student Teachers'"
        "'Teaching Staff'"
        'Govenors'
        "'Exam Candidate'"
    )

    [int]$year = (get-date).year
    for( $i = $year; $i -ge ($year -6); $i -= 1){
        "'$i Students'"
    }

    $preset |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($psitem, $psitem, 'ParameterValue', ("AD Name: " + $psitem))
        }
}

Export-ModuleMember -Function "*"
