# PipelineExample.ps1
# Demonstrates advanced pipeline operations using PSPoplar

param(
    [int]$DeviceId = 0,
    [string]$ModelPath = "",
    [switch]$UseMockData
)

Write-Host "=== PSPoplar Pipeline Example ===" -ForegroundColor Cyan

try {
    # Import the module
    Write-Host "Loading PSPoplar module..." -ForegroundColor Yellow
    Import-Module (Join-Path $PSScriptRoot "..\PSPoplar.psd1") -Force -Verbose:$false
    
    # Configure for optimal performance
    Write-Host "Configuring PSPoplar..." -ForegroundColor Yellow
    Set-PoplarConfiguration -DefaultDevice $DeviceId -EnableLogging $true -LogLevel "Information"
    $config = Get-PoplarConfiguration
    Write-Host "  Default Device: $($config.DefaultDevice)" -ForegroundColor Green
    Write-Host "  Logging: $($config.EnableLogging)" -ForegroundColor Green
    Write-Host "  Log Level: $($config.LogLevel)" -ForegroundColor Green
    
    # Create a comprehensive ML pipeline
    Write-Host "Creating ML pipeline..." -ForegroundColor Yellow
    $pipeline = New-PoplarPipeline -Name "MLInferencePipeline" -DeviceId $DeviceId
    if (-not $pipeline) {
        throw "Failed to create pipeline"
    }
    Write-Host "  Created pipeline: $($pipeline.Name)" -ForegroundColor Green
    
    # Step 1: Create computation graph
    Write-Host "Adding pipeline steps..." -ForegroundColor Yellow
    $pipeline | Add-PoplarPipelineStep -StepType "CreateGraph" -Parameters @{
        Name = "MainGraph"
    } | Out-Null
    Write-Host "  Added: CreateGraph step" -ForegroundColor Green
    
    # Step 2: Add input tensor
    $pipeline | Add-PoplarPipelineStep -StepType "AddTensor" -Parameters @{
        GraphName = "MainGraph"
        Name = "input_data"
        Shape = @(1, 128)  # Batch size 1, 128 features
        DataType = "Float"
    } | Out-Null
    Write-Host "  Added: AddTensor step (input)" -ForegroundColor Green
    
    # Step 3: Add output tensor
    $pipeline | Add-PoplarPipelineStep -StepType "AddTensor" -Parameters @{
        GraphName = "MainGraph"
        Name = "output_data"
        Shape = @(1, 10)   # Batch size 1, 10 classes
        DataType = "Float"
    } | Out-Null
    Write-Host "  Added: AddTensor step (output)" -ForegroundColor Green
    
    # Step 4: Create engine
    $pipeline | Add-PoplarPipelineStep -StepType "CreateEngine" -Parameters @{
        GraphName = "MainGraph"
        Name = "InferenceEngine"
    } | Out-Null
    Write-Host "  Added: CreateEngine step" -ForegroundColor Green
    
    # Step 5: Custom preprocessing step
    $pipeline | Add-PoplarPipelineStep -StepType "Custom" -Parameters @{
        ScriptBlock = {
            param($Pipeline, $Arguments)
            
            Write-Host "    Executing custom preprocessing step..." -ForegroundColor Cyan
            
            # Generate or load input data
            if ($Arguments.UseMockData) {
                $inputData = 1..128 | ForEach-Object { [float](Get-Random -Minimum 0.0 -Maximum 1.0) }
                Write-Host "    Generated mock input data (128 features)" -ForegroundColor White
            }
            else {
                # In a real scenario, this would load actual data
                $inputData = 1..128 | ForEach-Object { [float]0.5 }
                Write-Host "    Using default input data (128 features)" -ForegroundColor White
            }
            
            # Normalize data (example preprocessing)
            $mean = ($inputData | Measure-Object -Average).Average
            $normalizedData = $inputData | ForEach-Object { $_ - $mean }
            
            Write-Host "    Preprocessing completed (mean normalization)" -ForegroundColor White
            return [PSCustomObject]@{
                RawData = $inputData
                ProcessedData = $normalizedData
                Mean = $mean
                FeatureCount = $inputData.Count
            }
        }
        Arguments = @{
            UseMockData = $UseMockData.IsPresent
        }
    } | Out-Null
    Write-Host "  Added: Custom preprocessing step" -ForegroundColor Green
    
    # Step 6: Custom inference step
    $pipeline | Add-PoplarPipelineStep -StepType "Custom" -Parameters @{
        ScriptBlock = {
            param($Pipeline, $Arguments)
            
            Write-Host "    Executing custom inference step..." -ForegroundColor Cyan
            
            # Get the engine from pipeline resources
            $engine = $Pipeline.Resources.Engines["InferenceEngine"]
            if (-not $engine) {
                throw "Inference engine not found in pipeline resources"
            }
            
            # In a real scenario, this would run actual inference
            # For now, simulate inference results
            $outputData = 1..10 | ForEach-Object { [float](Get-Random -Minimum 0.0 -Maximum 1.0) }
            
            # Apply softmax normalization (example post-processing)
            $expValues = $outputData | ForEach-Object { [Math]::Exp($_) }
            $sumExp = ($expValues | Measure-Object -Sum).Sum
            $probabilities = $expValues | ForEach-Object { $_ / $sumExp }
            
            $maxProbIndex = 0
            $maxProb = $probabilities[0]
            for ($i = 1; $i -lt $probabilities.Count; $i++) {
                if ($probabilities[$i] -gt $maxProb) {
                    $maxProb = $probabilities[$i]
                    $maxProbIndex = $i
                }
            }
            
            Write-Host "    Inference completed (simulated)" -ForegroundColor White
            Write-Host "    Predicted class: $maxProbIndex (confidence: $([math]::Round($maxProb * 100, 2))%)" -ForegroundColor White
            
            return [PSCustomObject]@{
                RawOutput = $outputData
                Probabilities = $probabilities
                PredictedClass = $maxProbIndex
                Confidence = $maxProb
                ProcessingTime = (Get-Date)
            }
        }
        Arguments = @{}
    } | Out-Null
    Write-Host "  Added: Custom inference step" -ForegroundColor Green
    
    Write-Host "  Total pipeline steps: $($pipeline.Steps.Count)" -ForegroundColor Green
    
    # Display pipeline summary
    Write-Host "Pipeline Summary:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $pipeline.Steps.Count; $i++) {
        $step = $pipeline.Steps[$i]
        Write-Host "  Step $($i + 1): $($step.StepType) - $($step.Status)" -ForegroundColor Cyan
    }
    
    # Execute the pipeline with performance measurement
    Write-Host "Executing pipeline with performance measurement..." -ForegroundColor Yellow
    $executionResults = Measure-PoplarPerformance -ScriptBlock {
        Invoke-PoplarPipeline -Pipeline $pipeline -ContinueOnError
    } -Iterations 1
    
    Write-Host "Pipeline Execution Results:" -ForegroundColor Green
    $pipelineResults = $executionResults.Times[0]  # Get the actual pipeline results
    
    # Note: In a real implementation, Measure-PoplarPerformance would need to be modified
    # to return both timing and the actual results. For now, we'll execute again to get results.
    $pipelineResults = Invoke-PoplarPipeline -Pipeline $pipeline -ContinueOnError
    
    Write-Host "  Pipeline: $($pipelineResults.PipelineName)" -ForegroundColor Cyan
    Write-Host "  Total Steps: $($pipelineResults.TotalSteps)" -ForegroundColor White
    Write-Host "  Successful: $($pipelineResults.SuccessfulSteps)" -ForegroundColor Green
    Write-Host "  Failed: $($pipelineResults.FailedSteps)" -ForegroundColor $(if ($pipelineResults.FailedSteps -gt 0) { "Red" } else { "Green" })
    Write-Host "  Execution Time: $($pipelineResults.TotalExecutionTime.TotalSeconds) seconds" -ForegroundColor White
    
    # Display step results
    Write-Host "Step Results:" -ForegroundColor Yellow
    foreach ($result in $pipelineResults.Results) {
        $status = if ($result.Status -eq "Success") { "Green" } else { "Red" }
        Write-Host "  Step $($result.StepIndex + 1) ($($result.StepType)): $($result.Status)" -ForegroundColor $status
        
        if ($result.Status -eq "Failed") {
            Write-Host "    Error: $($result.Error)" -ForegroundColor Red
        }
        elseif ($result.Result -and $result.Result.PredictedClass -ne $null) {
            Write-Host "    Predicted Class: $($result.Result.PredictedClass)" -ForegroundColor White
            Write-Host "    Confidence: $([math]::Round($result.Result.Confidence * 100, 2))%" -ForegroundColor White
        }
        elseif ($result.Result -and $result.Result.FeatureCount) {
            Write-Host "    Features Processed: $($result.Result.FeatureCount)" -ForegroundColor White
            Write-Host "    Mean Value: $([math]::Round($result.Result.Mean, 4))" -ForegroundColor White
        }
    }
    
    # Demonstrate pipeline reuse
    Write-Host "Demonstrating pipeline reuse..." -ForegroundColor Yellow
    Write-Host "  Executing pipeline again with different data..." -ForegroundColor Cyan
    
    # Update the preprocessing step to use different data
    $pipeline.Steps[4].Parameters.Arguments.UseMockData = $true
    $secondResults = Invoke-PoplarPipeline -Pipeline $pipeline -ContinueOnError
    
    Write-Host "  Second execution completed:" -ForegroundColor Green
    Write-Host "    Successful steps: $($secondResults.SuccessfulSteps)/$($secondResults.TotalSteps)" -ForegroundColor White
    Write-Host "    Execution time: $($secondResults.TotalExecutionTime.TotalSeconds) seconds" -ForegroundColor White
    
    # Pipeline execution history
    Write-Host "Pipeline Execution History:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $pipeline.ExecutionHistory.Count; $i++) {
        $execution = $pipeline.ExecutionHistory[$i]
        Write-Host "  Execution $($i + 1): $($execution.SuccessfulSteps)/$($execution.TotalSteps) steps successful in $($execution.TotalExecutionTime.TotalSeconds)s" -ForegroundColor Cyan
    }
    
    Write-Host "=== Pipeline example completed successfully! ===" -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}
finally {
    # Clean up pipeline resources
    Write-Host "Cleaning up pipeline resources..." -ForegroundColor Yellow
    
    if ($pipeline) {
        Write-Host "  Cleaning up pipeline resources..." -ForegroundColor Gray
        
        # Clean up engines
        foreach ($engine in $pipeline.Resources.Engines.Values) {
            try { Remove-PoplarEngine -Engine $engine -ErrorAction SilentlyContinue } catch { }
        }
        
        # Clean up graphs
        foreach ($graph in $pipeline.Resources.Graphs.Values) {
            try { Remove-PoplarGraph -Graph $graph -ErrorAction SilentlyContinue } catch { }
        }
        
        # Clean up sessions
        foreach ($session in $pipeline.Resources.Sessions.Values) {
            try { Remove-PopARTSession -Session $session -ErrorAction SilentlyContinue } catch { }
        }
    }
    
    Write-Host "  Disconnecting devices..." -ForegroundColor Gray
    Disconnect-PoplarDevice -ErrorAction SilentlyContinue
    
    Write-Host "Cleanup completed." -ForegroundColor Yellow
}

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
