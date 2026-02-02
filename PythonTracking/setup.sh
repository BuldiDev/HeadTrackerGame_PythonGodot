#!/bin/bash
echo "========================================"
echo "  Head Tracking - Installazione Python"
echo "========================================"
echo ""

# Controlla se Python è installato
if ! command -v python3 &> /dev/null; then
    echo "[ERRORE] Python non trovato!"
    echo ""
    echo "Installa Python:"
    echo "  Ubuntu/Debian: sudo apt install python3 python3-pip"
    echo "  macOS: brew install python3"
    echo ""
    exit 1
fi

echo "[OK] Python trovato"
python3 --version
echo ""

# Installa dipendenze
echo "Installazione dipendenze..."
echo ""
pip3 install --user -r requirements.txt

if [ $? -ne 0 ]; then
    echo ""
    echo "[ERRORE] Installazione fallita!"
    exit 1
fi

echo ""
echo "========================================"
echo "  Installazione completata!"
echo "========================================"
echo ""
echo "Puoi ora avviare il progetto Godot."
echo "Il tracking si avvierà automaticamente."
echo ""
