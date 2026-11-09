@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo 사용법: install-claude-skill.bat ^<디렉토리명^>
    echo 예시:   install-claude-skill.bat commit-message
    exit /b 1
)

set "SOURCE_DIR=%~dp0%~1\.claude"
set "TARGET_DIR=%USERPROFILE%\.claude"

if not exist "%SOURCE_DIR%" (
    echo [오류] %SOURCE_DIR% 디렉토리가 없습니다.
    exit /b 1
)

echo [설치] %~1 의 에이전트/스킬을 글로벌 Claude 에 설치합니다.
echo        소스: %SOURCE_DIR%
echo        대상: %TARGET_DIR%
echo.

:: agents 복사
if exist "%SOURCE_DIR%\agents" (
    if not exist "%TARGET_DIR%\agents" mkdir "%TARGET_DIR%\agents"
    for %%f in ("%SOURCE_DIR%\agents\*.md") do (
        copy /y "%%f" "%TARGET_DIR%\agents\" >nul
        echo   [agents] %%~nxf 설치 완료
    )
) else (
    echo   [agents] 없음, 건너뜀
)

:: settings.json 복사 (에이전트 git 명령 차단 목록)
if exist "%SOURCE_DIR%\settings.json" (
    if exist "%TARGET_DIR%\settings.json" (
        set /p "CONFIRM=  [settings] %TARGET_DIR%\settings.json 이 이미 존재합니다. 덮어쓰시겠습니까? [y/N] "
        if /i "!CONFIRM!"=="y" (
            copy /y "%SOURCE_DIR%\settings.json" "%TARGET_DIR%\settings.json" >nul
            echo   [settings] settings.json 덮어쓰기 완료
        ) else (
            echo   [settings] settings.json 건너뜀
        )
    ) else (
        copy /y "%SOURCE_DIR%\settings.json" "%TARGET_DIR%\settings.json" >nul
        echo   [settings] settings.json 설치 완료
    )
) else (
    echo   [settings] 없음, 건너뜀
)

:: skills 복사 (하위 디렉토리 포함)
if exist "%SOURCE_DIR%\skills" (
    if not exist "%TARGET_DIR%\skills" mkdir "%TARGET_DIR%\skills"
    for /d %%d in ("%SOURCE_DIR%\skills\*") do (
        set "SKILL_NAME=%%~nxd"
        if not exist "%TARGET_DIR%\skills\!SKILL_NAME!" mkdir "%TARGET_DIR%\skills\!SKILL_NAME!"
        for %%f in ("%%d\*.md") do (
            copy /y "%%f" "%TARGET_DIR%\skills\!SKILL_NAME!\" >nul
            echo   [skills] !SKILL_NAME!/%%~nxf 설치 완료
        )
        if exist "%%d\scripts" (
            if not exist "%TARGET_DIR%\skills\!SKILL_NAME!\scripts" mkdir "%TARGET_DIR%\skills\!SKILL_NAME!\scripts"
            for %%s in ("%%d\scripts\*") do (
                copy /y "%%s" "%TARGET_DIR%\skills\!SKILL_NAME!\scripts\" >nul
                echo   [skills] !SKILL_NAME!/scripts/%%~nxs 설치 완료
            )
        )
        if exist "%%d\references" (
            if not exist "%TARGET_DIR%\skills\!SKILL_NAME!\references" mkdir "%TARGET_DIR%\skills\!SKILL_NAME!\references"
            for %%r in ("%%d\references\*") do (
                copy /y "%%r" "%TARGET_DIR%\skills\!SKILL_NAME!\references\" >nul
                echo   [skills] !SKILL_NAME!/references/%%~nxr 설치 완료
            )
        )
    )
) else (
    echo   [skills] 없음, 건너뜀
)

echo.
echo [완료] 설치가 끝났습니다. Claude Code 를 재시작하면 반영됩니다.
endlocal
