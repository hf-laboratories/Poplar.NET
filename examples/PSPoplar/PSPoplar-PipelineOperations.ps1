# PSPoplar-PipelineOperations.ps1
# Pipeline and configuration operations for PSPoplar module

#region Pipeline Operations

<#
.SYNOPSIS
Creates a new Poplar execution pipeline.

.DESCRIPTION
Creates a pipeline for chaining multiple Poplar operations together with automatic resource management.

.PARAMETER Name
Name for the pipeline.

.PARAMETER DeviceId
Target device ID for the pipeline.

.EXAMPLE
$pipeline = New-PoplarPipeline -Name "MLPipeline" -DeviceId 0
Creates a new pipeline named "MLPipeline" on device 0.
#>
function New-PoplarPipeline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [int]$DeviceId = $script:PoplarConfiguration.DefaultDevice
    )
    
    try {
        Write-Verbose "Creating pipeline '$Name' on device $DeviceId..."
        
        $pipeline = [PSCustomObject]@{
            Name = $Name
            DeviceId = $DeviceId
            Steps = @()
            Resources = @{
                Graphs = @{}
                Engines = @{}
                Sessions = @{}
                Tensors = @{}
            }
            CreatedTime = Get-Date
            IsExecuting = $false
            ExecutionHistory = @()
            Configuration = $script:PoplarConfiguration.Clone()
        }
        
        # Add pipeline methods
        $pipeline | Add-Member -MemberType ScriptMethod -Name "AddStep" -Value {
            param($StepType, $Parameters)
            $this.Steps += [PSCustomObject]@{
                StepType = $StepType
                Parameters = $Parameters
                Order = $this.Steps.Count
                Status = "Pending"
            }
        }
        
        $pipeline | Add-Member -MemberType ScriptMethod -Name "GetStep" -Value {
            param($Index)
            if ($Index -lt $this.Steps.Count) {
                return $this.Steps[$Index]
            }
            return $null
        }
        
        $pipeline | Add-Member -MemberType ScriptMethod -Name "RemoveStep" -Value {
            param($Index)
            if ($Index -lt $this.Steps.Count) {
                $this.Steps = $this.Steps | Where-Object { $_.Order -ne $Index }
                # Reorder remaining steps
                for ($i = 0; $i -lt $this.Steps.Count; $i++) {
                    $this.Steps[$i].Order = $i
                }
            }
        }
        
        Write-Verbose "Successfully created pipeline '$Name'"
        return $pipeline
    }
    catch {
        Write-Error "Failed to create pipeline: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Adds a step to a Poplar pipeline.

.DESCRIPTION
Adds an execution step to an existing Poplar pipeline.

.PARAMETER Pipeline
The pipeline to add the step to.

.PARAMETER StepType
Type of pipeline step (CreateGraph, AddTensor, CreateEngine, RunInference, etc.).

.PARAMETER Parameters
Parameters for the pipeline step.

.EXAMPLE
Add-PoplarPipelineStep -Pipeline $pipeline -StepType "CreateGraph" -Parameters @{Name="MainGraph"}
Adds a graph creation step to the pipeline.
#>
function Add-PoplarPipelineStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Pipeline,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("CreateGraph", "AddTensor", "CreateEngine", "LoadModel", "RunInference", "Custom")]
        [string]$StepType,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters
    )
    
    try {
        Write-Verbose "Adding step '$StepType' to pipeline '$($Pipeline.Name)'..."
        
        $Pipeline.AddStep($StepType, $Parameters)
        
        Write-Verbose "Successfully added step '$StepType'"
        return $Pipeline
    }
    catch {
        Write-Error "Failed to add pipeline step: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Executes a Poplar pipeline.

.DESCRIPTION
Executes all steps in a Poplar pipeline in order, managing resources automatically.

.PARAMETER Pipeline
The pipeline to execute.

.PARAMETER ContinueOnError
Continue executing remaining steps if an error occurs.

.PARAMETER Parallel
Execute compatible steps in parallel.

.EXAMPLE
$results = Invoke-PoplarPipeline -Pipeline $pipeline
Executes the pipeline and returns results.
#>
function Invoke-PoplarPipeline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Pipeline,
        
        [switch]$ContinueOnError,
        
        [switch]$Parallel
    )
    
    try {
        if ($Pipeline.IsExecuting) {
            throw "Pipeline is already executing"
        }
        
        Write-Verbose "Executing pipeline '$($Pipeline.Name)' with $($Pipeline.Steps.Count) steps..."
        
        $Pipeline.IsExecuting = $true
        $executionStart = Get-Date
        $results = @()
        
        # Execute steps
        for ($i = 0; $i -lt $Pipeline.Steps.Count; $i++) {
            $step = $Pipeline.Steps[$i]
            
            try {
                Write-Verbose "Executing step $($i + 1): $($step.StepType)..."
                $step.Status = "Executing"
                
                $stepResult = Invoke-PipelineStep -Pipeline $Pipeline -Step $step
                $step.Status = "Completed"
                
                $results += [PSCustomObject]@{
                    StepIndex = $i
                    StepType = $step.StepType
                    Status = "Success"
                    Result = $stepResult
                    ExecutionTime = (Get-Date) - $executionStart
                }
                
                Write-Verbose "Step $($i + 1) completed successfully"
            }
            catch {
                $step.Status = "Failed"
                $stepError = $_.Exception.Message
                
                $results += [PSCustomObject]@{
                    StepIndex = $i
                    StepType = $step.StepType
                    Status = "Failed"
                    Error = $stepError
                    ExecutionTime = (Get-Date) - $executionStart
                }
                
                Write-Error "Step $($i + 1) failed: $stepError"
                
                if (-not $ContinueOnError) {
                    break
                }
            }
        }
        
        $executionEnd = Get-Date
        $executionSummary = [PSCustomObject]@{
            PipelineName = $Pipeline.Name
            TotalSteps = $Pipeline.Steps.Count
            SuccessfulSteps = ($results | Where-Object { $_.Status -eq "Success" }).Count
            FailedSteps = ($results | Where-Object { $_.Status -eq "Failed" }).Count
            TotalExecutionTime = $executionEnd - $executionStart
            Results = $results
            ExecutionTime = $executionEnd
        }
        
        $Pipeline.ExecutionHistory += $executionSummary
        $Pipeline.IsExecuting = $false
        
        Write-Verbose "Pipeline execution completed in $($executionSummary.TotalExecutionTime.TotalSeconds) seconds"
        return $executionSummary
    }
    catch {
        $Pipeline.IsExecuting = $false
        Write-Error "Failed to execute pipeline: $($_.Exception.Message)"
        return $null
    }
}

function Invoke-PipelineStep {
    param(
        [PSCustomObject]$Pipeline,
        [PSCustomObject]$Step
    )
    
    switch ($Step.StepType) {
        "CreateGraph" {
            $graphName = $Step.Parameters.Name
            $graph = New-PoplarGraph -DeviceId $Pipeline.DeviceId -Name $graphName
            $Pipeline.Resources.Graphs[$graphName] = $graph
            return $graph
        }
        
        "AddTensor" {
            $graphName = $Step.Parameters.GraphName
            $tensorName = $Step.Parameters.Name
            $shape = $Step.Parameters.Shape
            $dataType = $Step.Parameters.DataType
            
            $graph = $Pipeline.Resources.Graphs[$graphName]
            if (-not $graph) {
                throw "Graph '$graphName' not found in pipeline resources"
            }
            
            $tensor = Add-PoplarTensor -Graph $graph -Shape $shape -DataType $dataType -Name $tensorName
            $Pipeline.Resources.Tensors[$tensorName] = $tensor
            return $tensor
        }
        
        "CreateEngine" {
            $graphName = $Step.Parameters.GraphName
            $engineName = $Step.Parameters.Name
            
            $graph = $Pipeline.Resources.Graphs[$graphName]
            if (-not $graph) {
                throw "Graph '$graphName' not found in pipeline resources"
            }
            
            $engine = New-PoplarEngine -Graph $graph -ProgramName $engineName
            $Pipeline.Resources.Engines[$engineName] = $engine
            return $engine
        }
        
        "LoadModel" {
            $modelPath = $Step.Parameters.ModelPath
            $sessionName = $Step.Parameters.Name
            
            $session = Import-ONNXModel -ModelPath $modelPath -SessionName $sessionName
            $Pipeline.Resources.Sessions[$sessionName] = $session
            return $session
        }
        
        "RunInference" {
            $sessionName = $Step.Parameters.SessionName
            $inputData = $Step.Parameters.InputData
            $outputSize = $Step.Parameters.OutputSize
            
            $session = $Pipeline.Resources.Sessions[$sessionName]
            if (-not $session) {
                throw "Session '$sessionName' not found in pipeline resources"
            }
            
            return Invoke-PoplarInference -Session $session -InputData $inputData -OutputSize $outputSize
        }
        
        "Custom" {
            $scriptBlock = $Step.Parameters.ScriptBlock
            $arguments = $Step.Parameters.Arguments
            
            return & $scriptBlock $Pipeline $arguments
        }
        
        default {
            throw "Unknown step type: $($Step.StepType)"
        }
    }
}

#endregion

#region Configuration Operations

<#
.SYNOPSIS
Sets Poplar module configuration.

.DESCRIPTION
Updates the global configuration settings for the PSPoplar module.

.PARAMETER Configuration
Hashtable containing configuration key-value pairs.

.PARAMETER DefaultDevice
Default device ID to use.

.PARAMETER EnableLogging
Enable or disable verbose logging.

.PARAMETER LogLevel
Logging level (Information, Warning, Error).

.PARAMETER TensorDataType
Default tensor data type.

.PARAMETER DefaultTimeout
Default timeout for operations in seconds.

.EXAMPLE
Set-PoplarConfiguration -DefaultDevice 1 -EnableLogging $true
Sets default device to 1 and enables logging.
#>
function Set-PoplarConfiguration {
    [CmdletBinding()]
    param(
        [hashtable]$Configuration,
        
        [int]$DefaultDevice,
        
        [bool]$EnableLogging,
        
        [ValidateSet("Information", "Warning", "Error")]
        [string]$LogLevel,
        
        [ValidateSet("Float", "Half", "Int", "UnsignedInt")]
        [string]$TensorDataType,
        
        [int]$DefaultTimeout
    )
    
    try {
        Write-Verbose "Updating Poplar configuration..."
        
        if ($Configuration) {
            foreach ($key in $Configuration.Keys) {
                $script:PoplarConfiguration[$key] = $Configuration[$key]
            }
        }
        
        if ($PSBoundParameters.ContainsKey('DefaultDevice')) {
            $script:PoplarConfiguration.DefaultDevice = $DefaultDevice
        }
        
        if ($PSBoundParameters.ContainsKey('EnableLogging')) {
            $script:PoplarConfiguration.EnableLogging = $EnableLogging
        }
        
        if ($PSBoundParameters.ContainsKey('LogLevel')) {
            $script:PoplarConfiguration.LogLevel = $LogLevel
        }
        
        if ($PSBoundParameters.ContainsKey('TensorDataType')) {
            $script:PoplarConfiguration.TensorDataType = $TensorDataType
        }
        
        if ($PSBoundParameters.ContainsKey('DefaultTimeout')) {
            $script:PoplarConfiguration.DefaultTimeout = $DefaultTimeout
        }
        
        Write-Verbose "Configuration updated successfully"
    }
    catch {
        Write-Error "Failed to set configuration: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
Gets the current Poplar module configuration.

.DESCRIPTION
Returns the current configuration settings for the PSPoplar module.

.EXAMPLE
Get-PoplarConfiguration
Returns the current configuration.
#>
function Get-PoplarConfiguration {
    [CmdletBinding()]
    param()
    
    return $script:PoplarConfiguration.Clone()
}

<#
.SYNOPSIS
Resets Poplar module configuration to defaults.

.DESCRIPTION
Resets all configuration settings to their default values.

.EXAMPLE
Reset-PoplarConfiguration
Resets configuration to defaults.
#>
function Reset-PoplarConfiguration {
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Resetting Poplar configuration to defaults..."
        
        $script:PoplarConfiguration = @{
            DefaultDevice = 0
            EnableLogging = $true
            LogLevel = "Information"
            TensorDataType = "Float"
            DefaultTimeout = 30
        }
        
        Write-Verbose "Configuration reset successfully"
    }
    catch {
        Write-Error "Failed to reset configuration: $($_.Exception.Message)"
    }
}

#endregion

#region Tensor Operations

<#
.SYNOPSIS
Creates a new tensor specification.

.DESCRIPTION
Creates a specification object for tensor creation with validation.

.PARAMETER Shape
Shape of the tensor as an array of dimensions.

.PARAMETER DataType
Data type of the tensor.

.PARAMETER Name
Name for the tensor.

.EXAMPLE
$spec = New-PoplarTensorSpec -Shape @(1, 128) -DataType "Float" -Name "input"
Creates a tensor specification.
#>
function New-PoplarTensorSpec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int[]]$Shape,
        
        [ValidateSet("Float", "Half", "Int", "UnsignedInt")]
        [string]$DataType = $script:PoplarConfiguration.TensorDataType,
        
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    try {
        # Validate shape
        if (-not (Test-PoplarTensorShape -Shape $Shape)) {
            throw "Invalid tensor shape"
        }
        
        $elementCount = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::CalculateElementCount($Shape)
        $sizeBytes = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::CalculateTensorSizeBytes($Shape, [HFLabs.IPUServices.PoplarBindings.PoplarDataType]::$DataType)
        
        $spec = [PSCustomObject]@{
            Name = $Name
            Shape = $Shape
            DataType = $DataType
            ElementCount = $elementCount
            SizeBytes = $sizeBytes
            FormattedShape = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::FormatShape($Shape)
            CreatedTime = Get-Date
            IsValid = $true
        }
        
        Write-Verbose "Created tensor spec '$Name' with shape $($spec.FormattedShape)"
        return $spec
    }
    catch {
        Write-Error "Failed to create tensor spec: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Validates a tensor shape.

.DESCRIPTION
Validates that a tensor shape array contains valid dimensions.

.PARAMETER Shape
Shape array to validate.

.EXAMPLE
Test-PoplarTensorShape -Shape @(1, 128, 64)
Returns $true if the shape is valid.
#>
function Test-PoplarTensorShape {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int[]]$Shape
    )
    
    try {
        if ($Shape.Length -eq 0) {
            Write-Verbose "Empty shape is invalid"
            return $false
        }
        
        foreach ($dim in $Shape) {
            if ($dim -le 0) {
                Write-Verbose "Dimension $dim is invalid (must be positive)"
                return $false
            }
        }
        
        # Check for reasonable limits
        $elementCount = 1
        foreach ($dim in $Shape) {
            $elementCount *= $dim
            if ($elementCount -gt [int]::MaxValue) {
                Write-Verbose "Tensor too large (exceeds maximum elements)"
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-Verbose "Shape validation failed: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
Converts data to Poplar tensor format.

.DESCRIPTION
Converts .NET arrays or other data structures to Poplar tensor format.

.PARAMETER Data
Data to convert.

.PARAMETER Shape
Target tensor shape.

.PARAMETER DataType
Target data type.

.EXAMPLE
$tensorData = ConvertTo-PoplarTensor -Data $array -Shape @(10, 10) -DataType "Float"
Converts array data to Poplar tensor format.
#>
function ConvertTo-PoplarTensor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Data,
        
        [Parameter(Mandatory = $true)]
        [int[]]$Shape,
        
        [ValidateSet("Float", "Half", "Int", "UnsignedInt")]
        [string]$DataType = $script:PoplarConfiguration.TensorDataType
    )
    
    try {
        # Validate shape
        if (-not (Test-PoplarTensorShape -Shape $Shape)) {
            throw "Invalid tensor shape"
        }
        
        $expectedElements = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::CalculateElementCount($Shape)
        
        # Convert data based on type and flatten if needed
        $flatData = @()
        
        if ($Data -is [Array]) {
            $flatData = $Data | ForEach-Object { $_ }
        }
        else {
            $flatData = @($Data)
        }
        
        if ($flatData.Count -ne $expectedElements) {
            throw "Data element count ($($flatData.Count)) does not match expected count ($expectedElements) for shape $([HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::FormatShape($Shape))"
        }
        
        # Convert to target data type
        $typedData = switch ($DataType) {
            "Float" { $flatData | ForEach-Object { [float]$_ } }
            "Half" { $flatData | ForEach-Object { [float]$_ } } # Will be converted to half in native code
            "Int" { $flatData | ForEach-Object { [int]$_ } }
            "UnsignedInt" { $flatData | ForEach-Object { [uint32]$_ } }
        }
        
        return [PSCustomObject]@{
            Data = $typedData
            Shape = $Shape
            DataType = $DataType
            ElementCount = $expectedElements
            FormattedShape = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::FormatShape($Shape)
        }
    }
    catch {
        Write-Error "Failed to convert to Poplar tensor: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Converts Poplar tensor data to .NET format.

.DESCRIPTION
Converts tensor data from Poplar format to standard .NET arrays.

.PARAMETER TensorData
Tensor data to convert.

.PARAMETER TargetShape
Optional target shape for reshaping.

.EXAMPLE
$array = ConvertFrom-PoplarTensor -TensorData $tensorData
Converts tensor data to .NET array.
#>
function ConvertFrom-PoplarTensor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $TensorData,
        
        [int[]]$TargetShape
    )
    
    try {
        if ($TensorData.Data) {
            $data = $TensorData.Data
        }
        else {
            $data = $TensorData
        }
        
        if ($TargetShape) {
            # Reshape data if target shape provided
            $expectedElements = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::CalculateElementCount($TargetShape)
            if ($data.Count -ne $expectedElements) {
                throw "Cannot reshape data with $($data.Count) elements to shape with $expectedElements elements"
            }
            
            # For now, return flattened array (full reshape logic would be more complex)
            return $data
        }
        
        return $data
    }
    catch {
        Write-Error "Failed to convert from Poplar tensor: $($_.Exception.Message)"
        return $null
    }
}

#endregion

# Export additional functions
Export-ModuleMember -Function New-PoplarPipeline, Add-PoplarPipelineStep, Invoke-PoplarPipeline
Export-ModuleMember -Function Set-PoplarConfiguration, Get-PoplarConfiguration, Reset-PoplarConfiguration
Export-ModuleMember -Function New-PoplarTensorSpec, ConvertTo-PoplarTensor, ConvertFrom-PoplarTensor, Test-PoplarTensorShape
