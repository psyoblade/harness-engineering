@echo off
setlocal

if "%~1"=="" (
    echo 사용법: install-claude-hook.bat ^<디렉토리명^>
    echo 예시:   install-claude-hook.bat learning-mode
    exit /b 1
)

set "SOURCE_DIR=%~dp0%~1\.claude"
set "TARGET_DIR=%USERPROFILE%\.claude"

if not exist "%SOURCE_DIR%\hooks" (
    echo [오류] %SOURCE_DIR%\hooks 디렉토리가 없습니다.
    exit /b 1
)

echo [설치] %~1 의 훅을 글로벌 Claude 에 설치합니다.
echo        소스: %SOURCE_DIR%
echo        대상: %TARGET_DIR%
echo.

:: hooks 복사 (스크립트와 스크립트가 읽는 파일)
if not exist "%TARGET_DIR%\hooks" mkdir "%TARGET_DIR%\hooks"
for %%f in ("%SOURCE_DIR%\hooks\*") do (
    copy /y "%%f" "%TARGET_DIR%\hooks\" >nul
    echo   [hooks] %%~nxf 설치 완료
)

:: settings.json 에 훅 등록 (덮어쓰지 않고 병합, 같은 명령의 기존 등록은 교체, 기존 파일은 settings.json.bak-<시각> 으로 백업)
if not exist "%SOURCE_DIR%\hooks.json" (
    echo   [settings] hooks.json 없음, 건너뜀
    goto :done
)
set "PS=powershell"
where pwsh >nul 2>&1 && set "PS=pwsh"
if "%PS%"=="powershell" (
    echo   [경고] PowerShell 7^(pwsh^)이 없어 Windows PowerShell 5.1 로 병합합니다. 내용은 같지만 settings.json 전체의 들여쓰기가 바뀝니다.
)
%PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0merge-claude-hooks.ps1" -HooksJson "%SOURCE_DIR%\hooks.json" -Settings "%TARGET_DIR%\settings.json" -ClaudeHome "%TARGET_DIR%"
if errorlevel 1 (
    echo [오류] settings.json 병합에 실패했습니다. 기존 파일은 그대로입니다.
    exit /b 1
)

:done
echo.
echo [완료] 설치가 끝났습니다. Claude Code 를 재시작하면 반영됩니다.
endlocal
