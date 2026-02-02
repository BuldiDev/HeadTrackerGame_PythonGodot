@echo off
echo ========================================
echo   Head Tracking - Installazione Python
echo ========================================
echo.

:: Controlla se Python è installato
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERRORE] Python non trovato!
    echo.
    echo Scarica e installa Python da: https://www.python.org/downloads/
    echo Assicurati di selezionare "Add Python to PATH" durante l'installazione.
    echo.
    pause
    exit /b 1
)

echo [OK] Python trovato
python --version
echo.

:: Installa dipendenze
echo Installazione dipendenze...
echo.
pip install --user -r requirements.txt

if %errorlevel% neq 0 (
    echo.
    echo [ERRORE] Installazione fallita!
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Installazione completata!
echo ========================================
echo.
echo Puoi ora avviare il progetto Godot.
echo Il tracking si avvierà automaticamente.
echo.
pause
