param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("init", "validate", "plan", "apply", "destroy", "fmt", "test", "clean", "status")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TfvarsFile = "terraform.tfvars"
$LogFile = "terraform_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

$Colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
    Debug = "Gray"
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Success", "Error", "Warning", "Info", "Debug")]
        [string]$Level = "Info"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    Write-Host $LogMessage -ForegroundColor $Colors[$Level]
    Add-Content -Path $LogFile -Value $LogMessage
}

function Test-Requirements {
    Write-Log "Verificando requisitos..." -Level Info
    
    $requirements = @{
        "terraform" = "terraform --version"
        "aws" = "aws --version"
    }
    
    foreach ($req in $requirements.GetEnumerator()) {
        try {
            $result = Invoke-Expression $req.Value 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "✓ $($req.Key) instalado" -Level Success
            }
        }
        catch {
            Write-Log "✗ $($req.Key) NO está instalado" -Level Error
            return $false
        }
    }
    
    return $true
}

function Test-TfvarsExists {
    if (-not (Test-Path $TfvarsFile)) {
        Write-Log "⚠ $TfvarsFile no existe. Creando desde ejemplo..." -Level Warning
        
        if (Test-Path "terraform.tfvars.example") {
            Copy-Item "terraform.tfvars.example" $TfvarsFile
            Write-Log "✓ $TfvarsFile creado desde terraform.tfvars.example" -Level Success
            Write-Log "⚠ IMPORTANTE: Edita $TfvarsFile y configura los valores antes de continuar" -Level Warning
            return $false
        }
        else {
            Write-Log "✗ No se encontró terraform.tfvars.example" -Level Error
            return $false
        }
    }
    
    return $true
}

function Invoke-TerraformInit {
    Write-Log "Inicializando Terraform..." -Level Info
    
    try {
        terraform init
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ Terraform inicializado correctamente" -Level Success
            return $true
        }
        else {
            Write-Log "✗ Error en terraform init" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "✗ Error ejecutando terraform init: $_" -Level Error
        return $false
    }
}

function Invoke-TerraformValidate {
    Write-Log "Validando configuración Terraform..." -Level Info
    
    try {
        terraform validate
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ Configuración válida" -Level Success
            return $true
        }
        else {
            Write-Log "✗ Errores de validación detectados" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "✗ Error en terraform validate: $_" -Level Error
        return $false
    }
}

function Invoke-TerraformFormat {
    Write-Log "Formateando código Terraform..." -Level Info
    
    try {
        terraform fmt -recursive
        Write-Log "✓ Código formateado" -Level Success
        return $true
    }
    catch {
        Write-Log "✗ Error en terraform fmt: $_" -Level Error
        return $false
    }
}

function Invoke-TerraformPlan {
    Write-Log "Creando plan Terraform..." -Level Info
    
    if (-not (Test-TfvarsExists)) {
        Write-Log "✗ terraform.tfvars no configurado" -Level Error
        return $false
    }
    
    try {
        $PlanFile = "tfplan_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        terraform plan -out=$PlanFile
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ Plan creado exitosamente: $PlanFile" -Level Success
            Write-Log "Próximo paso: iac apply" -Level Info
            return $true
        }
        else {
            Write-Log "✗ Error creando plan" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "✗ Error en terraform plan: $_" -Level Error
        return $false
    }
}

function Invoke-TerraformApply {
    Write-Log "Aplicando Terraform..." -Level Info
    
    if (-not (Test-TfvarsExists)) {
        Write-Log "✗ terraform.tfvars no configurado" -Level Error
        return $false
    }
    
    try {
        # Buscar plan más reciente
        $LatestPlan = Get-ChildItem -Filter "tfplan_*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if ($LatestPlan) {
            Write-Log "Usando plan: $($LatestPlan.Name)" -Level Info
            terraform apply $LatestPlan.Name
        }
        else {
            Write-Log "No se encontró plan previo. Crear uno primero con: iac plan" -Level Warning
            return $false
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ Infraestructura aplicada exitosamente" -Level Success
            Write-Log "Ver outputs: iac status" -Level Info
            return $true
        }
        else {
            Write-Log "✗ Error aplicando Terraform" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "✗ Error en terraform apply: $_" -Level Error
        return $false
    }
}

function Invoke-TerraformDestroy {
    Write-Log "⚠️ ADVERTENCIA: Esto eliminará toda la infraestructura" -Level Warning
    $Confirm = Read-Host "¿Estás seguro? (escribe 'SI' para confirmar)"
    
    if ($Confirm -ne "SI") {
        Write-Log "Operación cancelada" -Level Info
        return $false
    }
    
    if (-not (Test-TfvarsExists)) {
        Write-Log "✗ terraform.tfvars no configurado" -Level Error
        return $false
    }
    
    try {
        terraform destroy -auto-approve
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ Infraestructura destruida" -Level Success
            return $true
        }
        else {
            Write-Log "✗ Error en terraform destroy" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "✗ Error en terraform destroy: $_" -Level Error
        return $false
    }
}

function Test-LambdaCode {
    Write-Log "Testeando código Lambda..." -Level Info
    
    if (-not (Test-Path "test_lambda.py")) {
        Write-Log "✗ test_lambda.py no encontrado" -Level Error
        return $false
    }
    
    try {
        python test_lambda.py
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ Tests de Lambda pasados" -Level Success
            return $true
        }
        else {
            Write-Log "✗ Tests de Lambda fallaron" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "✗ Error ejecutando tests: $_" -Level Error
        return $false
    }
}

function Invoke-TerraformStatus {
    Write-Log "Estado actual de la infraestructura:" -Level Info
    
    try {
        Write-Host "`n--- Outputs ---`n" -ForegroundColor Cyan
        terraform output
        
        Write-Host "`n--- Recursos ---`n" -ForegroundColor Cyan
        terraform state list
        
        return $true
    }
    catch {
        Write-Log "✗ Error obteniendo estado: $_" -Level Error
        return $false
    }
}

function Invoke-Clean {
    Write-Log "Limpiando archivos temporales..." -Level Info
    
    $filesToRemove = @(
        "lambda_function.zip",
        "lambda_layer.zip",
        ".terraform",
        "terraform.tfstate*",
        ".terraform.lock.hcl"
    )
    
    foreach ($file in $filesToRemove) {
        if (Test-Path $file) {
            Remove-Item -Path $file -Recurse -Force
            Write-Log "✓ Removido: $file" -Level Success
        }
    }
    
    Write-Log "✓ Limpieza completada" -Level Success
    return $true
}

function Main {
    Write-Host "IAC - Infrastructure as Code Automation Script" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Log "Acción: $Action | Ambiente: $Environment" -Level Info
    
    if (-not (Test-Requirements)) {
        Write-Log "✗ Requisitos no cumplidos" -Level Error
        exit 1
    }
    
    $Success = $false
    
    switch ($Action) {
        "init" {
            $Success = (Invoke-TerraformValidate) -and (Invoke-TerraformInit)
        }
        "validate" {
            $Success = Invoke-TerraformValidate
        }
        "plan" {
            $Success = Invoke-TerraformPlan
        }
        "apply" {
            $Success = Invoke-TerraformApply
        }
        "destroy" {
            $Success = Invoke-TerraformDestroy
        }
        "fmt" {
            $Success = Invoke-TerraformFormat
        }
        "test" {
            $Success = Test-LambdaCode
        }
        "clean" {
            $Success = Invoke-Clean
        }
        "status" {
            $Success = Invoke-TerraformStatus
        }
    }
    
    Write-Host ""
    if ($Success) {
        Write-Log "✓ Operación completada exitosamente" -Level Success
        exit 0
    }
    else {
        Write-Log "✗ Operación falló. Ver logs: $LogFile" -Level Error
        exit 1
    }
}

Main
