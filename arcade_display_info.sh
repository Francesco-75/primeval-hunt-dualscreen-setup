#!/bin/bash
# ============================================================
#  arcade_display_info.sh — Raccoglie informazioni sui monitor
#  Da eseguire sulla macchina arcade con entrambi i monitor
#  collegati e la sessione X11 attiva.
#  Produce un file di log con tutto il necessario per
#  configurare correttamente xrandr e la modeline 640x480.
#
#  Uso: ./arcade_display_info.sh
#  Output: arcade_display_info_TIMESTAMP.log
# ============================================================

SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
LOG="${SELFDIR}/arcade_display_info_${TIMESTAMP}.log"

# ── Colori ────────────────────────────────────────────────
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; NC='\033[0m'

info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

# ── Scrive su log e stdout ────────────────────────────────
log() {
    echo "$*" | tee -a "$LOG"
}
logsep() {
    log ""
    log "════════════════════════════════════════════════════════"
    log "  $*"
    log "════════════════════════════════════════════════════════"
}

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║      ARCADE DISPLAY INFO — Raccolta dati     ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# Verifica che X11 sia attivo
if [[ -z "${DISPLAY:-}" ]]; then
    echo -e "${YELLOW}[WARN]${NC}  Variabile DISPLAY non impostata."
    echo -e "       Assicurati di eseguire lo script in una sessione X11."
    echo -e "       Se sei in SSH, aggiungi: export DISPLAY=:0"
    exit 1
fi

info "Avvio raccolta informazioni display..."
info "Log: $LOG"
echo ""

# ── Installazione automatica tool di decodifica EDID ─────
# edid-decode è il tool principale per decodificare l'EDID in
# forma leggibile. parse-edid (dal pacchetto read-edid) è un
# fallback. Se i repo sono congelati (sources.list.FROZEN) apt
# fallirà — in quel caso avvisiamo senza bloccare lo script.

# Installiamo edid-decode (analisi completa) e read-edid (contiene
# parse-edid, produce output in formato xorg.conf — utile per ricavare
# HorizSync e VertRefresh pronti all'uso). I due tool sono complementari
# e vengono entrambi eseguiti per ogni monitor con log su file separati.
NEED_INSTALL=()
command -v edid-decode &>/dev/null || NEED_INSTALL+=(edid-decode)
command -v parse-edid  &>/dev/null || NEED_INSTALL+=(read-edid)

if [[ ${#NEED_INSTALL[@]} -gt 0 ]]; then
    info "Tool mancanti: ${NEED_INSTALL[*]} — tento installazione..."

    SOURCES=/etc/apt/sources.list
    if [[ ! -f "$SOURCES" && -f "${SOURCES}.FROZEN" ]]; then
        echo ""
        echo -e "${YELLOW}${BOLD}  ╔══════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}${BOLD}  ║  ATTENZIONE: repository APT congelati!       ║${NC}"
        echo -e "${YELLOW}${BOLD}  ╠══════════════════════════════════════════════╣${NC}"
        echo -e "${YELLOW}${BOLD}  ║${NC}  sources.list.FROZEN trovato — apt non può   ${YELLOW}${BOLD}║${NC}"
        echo -e "${YELLOW}${BOLD}  ║${NC}  installare i tool di decodifica EDID.       ${YELLOW}${BOLD}║${NC}"
        echo -e "${YELLOW}${BOLD}  ║${NC}                                              ${YELLOW}${BOLD}║${NC}"
        echo -e "${YELLOW}${BOLD}  ║${NC}  Esegui prima: ./arcade_unfreeze.sh          ${YELLOW}${BOLD}║${NC}"
        echo -e "${YELLOW}${BOLD}  ║${NC}  oppure installa manualmente:                ${YELLOW}${BOLD}║${NC}"
        echo -e "${YELLOW}${BOLD}  ║${NC}    sudo apt install ${NEED_INSTALL[*]}         ${YELLOW}${BOLD}║${NC}"
        echo -e "${YELLOW}${BOLD}  ╚══════════════════════════════════════════════╝${NC}"
        echo ""
        warn "Proseguo senza decodifica EDID avanzata — dati parziali."
        echo "WARN: repo congelati, ${NEED_INSTALL[*]} non installati" >> "$LOG"
    else
        info "Aggiorno le liste APT..."
        sudo apt update -qq 2>&1 | tee -a "$LOG"
        info "Installo: ${NEED_INSTALL[*]}..."
        if sudo apt install -y "${NEED_INSTALL[@]}" 2>&1 | tee -a "$LOG"; then
            ok "Installati: ${NEED_INSTALL[*]}"
        else
            warn "Installazione fallita — proseguo con decodifica limitata."
        fi
    fi
else
    ok "edid-decode e parse-edid già presenti."
fi
echo ""

# ── Intestazione log ──────────────────────────────────────
log "arcade_display_info.sh — $(date '+%Y-%m-%d %H:%M:%S')"
log "Hostname: $(hostname)"
log "Utente:   $(whoami)"
log "DISPLAY:  $DISPLAY"

# ════════════════════════════════════════════════════════════
# 1. GPU e driver
# ════════════════════════════════════════════════════════════
logsep "1. GPU e driver"

log "--- lspci (VGA/Display) ---"
lspci | grep -E "VGA|Display|3D" | tee -a "$LOG"

log ""
log "--- Versione driver nvidia (se installato) ---"
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | tee -a "$LOG"
else
    log "(nvidia-smi non trovato)"
fi

log ""
log "--- Modulo kernel attivo ---"
lsmod | grep -E "nvidia|nouveau|i915|amdgpu|radeon" | tee -a "$LOG" || log "(nessun modulo video rilevato)"

# ════════════════════════════════════════════════════════════
# 2. xrandr: uscite e risoluzioni rilevate
# ════════════════════════════════════════════════════════════
logsep "2. xrandr — uscite e risoluzioni rilevate"

log "--- xrandr --query ---"
xrandr --query 2>&1 | tee -a "$LOG"

# ════════════════════════════════════════════════════════════
# 3. xrandr verbose: EDID completo e range frequenze
# ════════════════════════════════════════════════════════════
logsep "3. xrandr --verbose — EDID e range frequenze"
log "(Questa sezione contiene i dati EDID grezzi di ogni monitor)"
log ""

xrandr --verbose 2>&1 | tee -a "$LOG"

# ════════════════════════════════════════════════════════════
# 4. Uscite connesse: riepilogo rapido
# ════════════════════════════════════════════════════════════
logsep "4. Riepilogo uscite connesse"

log "--- Uscite CONNESSE con risoluzione attiva ---"
xrandr --query | grep " connected" | tee -a "$LOG"

log ""
log "--- Risoluzione desktop virtuale totale ---"
xrandr --query | grep "Screen 0" | tee -a "$LOG"

# ════════════════════════════════════════════════════════════
# 5. Verifica se 640x480 è già disponibile
# ════════════════════════════════════════════════════════════
logsep "5. Verifica disponibilità 640x480"

OUTPUTS_CONNECTED=$(xrandr --query | grep " connected" | awk '{print $1}')
log "Uscite connesse: $OUTPUTS_CONNECTED"
log ""

for output in $OUTPUTS_CONNECTED; do
    log "--- $output ---"
    # Cerca 640x480 tra le modalità disponibili
    if xrandr --query | grep -A50 "^${output} connected" | grep -q "640x480"; then
        log "  ✓ 640x480 PRESENTE nell'EDID di $output"
        xrandr --query | grep -A50 "^${output} connected" | grep "640x480" | tee -a "$LOG"
    else
        log "  ✗ 640x480 NON presente nell'EDID di $output — andrà aggiunta via modeline"
    fi
    log ""
done

# ════════════════════════════════════════════════════════════
# 6. Range frequenze da EDID (estratto da verbose)
# ════════════════════════════════════════════════════════════
logsep "6. Range frequenze EDID (HorizSync / VertRefresh)"

for output in $OUTPUTS_CONNECTED; do
    log "--- $output ---"
    # Estrae i range dal blocco verbose
    xrandr --verbose | awk "/^${output} connected/,/^[^ ]/" | \
        grep -E "HorizSync|VertRefresh|Bandwidth|range" | tee -a "$LOG" || \
        log "  (range non trovati nell'EDID di $output)"
    log ""
done

# ════════════════════════════════════════════════════════════
# 7. Modalità attualmente attive
# ════════════════════════════════════════════════════════════
logsep "7. Modalità attualmente attive per uscita"

for output in $OUTPUTS_CONNECTED; do
    log "--- $output ---"
    xrandr --query | grep -A50 "^${output} connected" | grep "\*" | tee -a "$LOG" || \
        log "  (nessuna modalità attiva trovata)"
    log ""
done

# ════════════════════════════════════════════════════════════
# 8. Test modeline VESA 640x480@60Hz
# ════════════════════════════════════════════════════════════
logsep "8. Test modeline VESA 640x480@60Hz"

log "Modeline standard VESA per 640x480@60Hz:"
log "  25.18 640 656 752 800 480 490 492 525 -hsync -vsync"
log ""
log "Tentativo di aggiunta modeline (test non distruttivo)..."

# Prova ad aggiungere la modeline — se fallisce indica il problema
xrandr --newmode "640x480_test" 25.18 640 656 752 800 480 490 492 525 -hsync -vsync 2>&1 | tee -a "$LOG"
NEWMODE_RC=${PIPESTATUS[0]}

if [[ $NEWMODE_RC -eq 0 ]]; then
    log "  ✓ Modeline accettata da xrandr"
    # Prova ad aggiungerla alle uscite connesse
    for output in $OUTPUTS_CONNECTED; do
        result=$(xrandr --addmode "$output" 640x480_test 2>&1)
        if [[ -z "$result" ]]; then
            log "  ✓ Modeline aggiunta a $output"
        else
            log "  ✗ Errore aggiunta a $output: $result"
        fi
    done
    # Rimuove la modalità di test (pulizia)
    for output in $OUTPUTS_CONNECTED; do
        xrandr --delmode "$output" 640x480_test 2>/dev/null
    done
    xrandr --rmmode "640x480_test" 2>/dev/null
    log "  (modalità di test rimossa — era solo un test)"
else
    log "  ✗ Modeline rifiutata — potrebbe già esistere con altro nome"
fi

# ════════════════════════════════════════════════════════════
# 9. EDID binario e decodificato — tre metodi in cascata
# ════════════════════════════════════════════════════════════
logsep "9. EDID — estrazione e decodifica per ogni monitor"

# Con i driver nvidia proprietari recenti /sys/class/drm/ non espone
# l'EDID, quindi usiamo tre metodi in cascata per ogni uscita connessa:
#
# METODO 1 — get-edid (dal pacchetto read-edid):
#   Legge l'EDID via DDC/CI direttamente dall'hardware bypassando
#   il driver. Richiede accesso a /dev/i2c-* (di solito ok con sudo).
#
# METODO 2 — xrandr --verbose (estrazione hex):
#   L'EDID grezzo è già presente nel log della sezione 3 in formato
#   hex. Lo estraiamo, lo convertiamo in binario e lo usiamo come
#   sorgente per edid-decode e parse-edid.
#
# METODO 3 — fallback hex grezzo:
#   Se nessun metodo produce un binario valido, logghiamo almeno
#   l'hex grezzo estratto da xrandr --verbose per analisi manuale.

# ── Funzione: decodifica un file EDID binario ─────────────
# Argomenti: decode_edid /path/file.bin "nome_output"
decode_edid_bin() {
    local bin_file="$1"
    local output_name="$2"

    # edid-decode: analisi completa con tutti i blocchi e timing
    edid_log="${SELFDIR}/edid-decode_${output_name}_${TIMESTAMP}.log"
    if command -v edid-decode &>/dev/null; then
        {
            echo "edid-decode — ${output_name} — $(date '+%Y-%m-%d %H:%M:%S')"
            echo "Sorgente EDID: $bin_file"
            echo ""
            edid-decode < "$bin_file" 2>&1
        } > "$edid_log"
        cat "$edid_log" >> "$LOG"
        log "  → edid-decode: $(basename "$edid_log")"
    else
        log "  (edid-decode non disponibile)"
    fi

    # parse-edid: output in formato xorg.conf con HorizSync/VertRefresh
    parse_log="${SELFDIR}/parse-edid_${output_name}_${TIMESTAMP}.log"
    if command -v parse-edid &>/dev/null; then
        {
            echo "parse-edid — ${output_name} — $(date '+%Y-%m-%d %H:%M:%S')"
            echo "Sorgente EDID: $bin_file"
            echo ""
            parse-edid < "$bin_file" 2>&1
        } > "$parse_log"
        cat "$parse_log" >> "$LOG"
        log "  → parse-edid: $(basename "$parse_log")"
    else
        log "  (parse-edid non disponibile)"
    fi
}

# ── Funzione: estrae EDID hex da xrandr --verbose ────────
# Argomenti: extract_edid_xrandr "nome_output"
# Scrive il file .bin in SELFDIR e stampa il path se ok,
# stringa vuota se fallisce. Usa un file python temporaneo
# per evitare problemi con here-doc nested in subshell.
extract_edid_xrandr() {
    local out_name="$1"
    local bin_file="${SELFDIR}/edid_${out_name}_${TIMESTAMP}.bin"

    # Scrive il parser python in un file temporaneo per evitare
    # problemi di quoting/nesting con here-doc dentro $()
    local py_tmp
    py_tmp=$(mktemp /tmp/edid_parser_XXXXXX.py)
    cat > "$py_tmp" << 'PYEOF'
import sys, re
target = sys.argv[1]
in_target = False
in_edid   = False
hex_lines = []
for line in sys.stdin:
    m = re.match(r'^(\S+)\s+(connected|disconnected)', line)
    if m:
        in_target = (m.group(1) == target)
        in_edid   = False
        continue
    if not in_target:
        continue
    if re.match(r'^\s+EDID:\s*$', line):
        in_edid = True
        continue
    if in_edid:
        stripped = line.strip()
        if re.match(r'^[0-9a-f]{32}$', stripped):
            hex_lines.append(stripped)
        else:
            in_edid = False
print(''.join(hex_lines))
PYEOF

    local edid_hex
    edid_hex=$(xrandr --verbose 2>/dev/null | python3 "$py_tmp" "$out_name")
    rm -f "$py_tmp"

    if [[ -n "$edid_hex" ]] && [[ ${#edid_hex} -ge 256 ]]; then
        echo "$edid_hex" | xxd -r -p > "$bin_file" 2>/dev/null
        if [[ -s "$bin_file" ]]; then
            local header
            header=$(xxd "$bin_file" 2>/dev/null | head -1 | awk '{print $2$3}')
            if [[ "$header" == "00ffffff"* ]]; then
                echo "$bin_file"
                return 0
            fi
        fi
        rm -f "$bin_file"
    fi
    echo ""
    return 1
}

# ── Itera su ogni uscita connessa ─────────────────────────
for output in $OUTPUTS_CONNECTED; do
    log ""
    log "════ $output ════"
    edid_bin="${SELFDIR}/edid_${output}_${TIMESTAMP}.bin"
    EDID_OK=0

    # ── Menu interattivo: scelta metodo di estrazione EDID ──
    # Per ogni uscita l'utente sceglie esplicitamente il metodo.
    # Default [1] = get-edid via DDC/CI (metodo hardware diretto).
    # Questo permette anche di testare il metodo 2 indipendentemente
    # dal metodo 1 senza dover modificare lo script.
    echo ""
    echo -e "${CYAN}${BOLD}  ── Uscita: $output ──────────────────────────────────${NC}"
    echo -e "  Come vuoi estrarre l'EDID per ${BOLD}${output}${NC}?"
    echo ""
    echo -e "  ${GREEN}[1]${NC} get-edid via DDC/CI    (lettura hardware diretta dal bus I2C)"
    echo -e "      ${GREEN}★ CONSIGLIATO${NC} — legge l'EDID direttamente dal monitor"
    echo -e "      bypassando driver e X11. È la fonte più affidabile."
    echo ""
    echo -e "  ${CYAN}[2]${NC} xrandr --verbose        (estrazione hex dalla sessione X11)"
    echo -e "      Utile se il metodo 1 fallisce. Dipende da quello che"
    echo -e "      xrandr riceve dal driver nvidia (può essere filtrato)."
    echo ""
    echo -e "  ${YELLOW}[3]${NC} Solo hex grezzo         (fallback — nessun file .bin)"
    echo -e "      Solo per diagnosi manuale, non produce file decodificati."
    echo ""
    echo -e "  ${RED}[0]${NC} Salta questa uscita"
    echo ""
    read -rp "  Scelta [default: 1]: " metodo_scelta
    metodo_scelta="${metodo_scelta:-1}"
    _log ">>> $output: scelta metodo '$metodo_scelta'"

    case "$metodo_scelta" in

    1)
        # ── METODO 1: get-edid via DDC/CI con bus I2C specifico ──
        # get-edid legge l'EDID via DDC/CI dal bus I2C del monitor.
        # IMPORTANTE: senza specificare il bus (-b N) get-edid legge
        # solo il primo monitor che risponde, ignorando gli altri.
        # Dobbiamo abbinare ogni uscita xrandr al suo bus I2C cercando
        # in /sys/class/drm/card*-USCITA/ la sottocartella i2c-N.
        # Funziona con nvidia proprietario e con qualsiasi numero
        # di uscite (2, 3 o più monitor).
        log ""
        log "  [Metodo 1] get-edid via DDC/CI (bus I2C specifico per $output)..."
        if command -v get-edid &>/dev/null; then
            # Trova il numero di bus I2C per questa uscita specifica.
            # nvidia espone il bus come sottocartella i2c-N dentro
            # /sys/class/drm/card*-USCITA/ dove USCITA usa trattini
            # (es. card0-DVI-D-0, card0-HDMI-A-0, card0-DP-1 ecc.)
            # Il nome in sysfs può differire da xrandr (HDMI-0 vs HDMI-A-0):
            # cerchiamo tutte le card*- che contengono il nome dell'uscita.
            I2C_BUS=""
            for drm_path in /sys/class/drm/card*-*/; do
                drm_name=$(basename "$drm_path")
                out_sysfs="${drm_name#card*-}"
                out_base=$(echo "$output" | sed 's/-[0-9]*$//')
                out_num=$(echo "$output" | grep -o '[0-9]*$')
                sysfs_base=$(echo "$out_sysfs" | sed 's/-[A-Z]*-[0-9]*$//' | sed 's/-[0-9]*$//')
                sysfs_num=$(echo "$out_sysfs" | grep -o '[0-9]*$')
                if [[ "$out_base" == "$sysfs_base" && "$out_num" == "$sysfs_num" ]] || \
                   [[ "$output" == "$out_sysfs" ]]; then
                    i2c_path=$(find "$drm_path" -maxdepth 1 -name "i2c-*" -type d 2>/dev/null | head -1)
                    if [[ -n "$i2c_path" ]]; then
                        I2C_BUS=$(basename "$i2c_path" | sed 's/i2c-//')
                        _log "    Trovato bus I2C: $i2c_path → bus $I2C_BUS"
                        break
                    fi
                fi
            done

            if [[ -n "$I2C_BUS" ]]; then
                log "  Bus I2C rilevato: $I2C_BUS → get-edid -b $I2C_BUS"
                if sudo get-edid -b "$I2C_BUS" 2>/dev/null > "$edid_bin" && [[ -s "$edid_bin" ]]; then
                    header=$(xxd "$edid_bin" 2>/dev/null | head -1 | awk '{print $2$3}')
                    if [[ "$header" == "00ffffff"* ]]; then
                        log "  ✓ EDID letto via get-edid -b $I2C_BUS — header valido ($header)"
                        log "  Salvato: $(basename "$edid_bin")"
                        EDID_OK=1
                    else
                        log "  ✗ Header EDID non valido: $header"
                        rm -f "$edid_bin"
                    fi
                else
                    log "  ✗ get-edid -b $I2C_BUS fallito (monitor non risponde via DDC)"
                    rm -f "$edid_bin"
                fi
            else
                log "  ✗ Bus I2C non trovato per $output in /sys/class/drm/"
                log "    (normale con driver nvidia proprietari recenti)"
            fi
        else
            log "  (get-edid non installato)"
        fi
        ;;

    2)
        log ""
        log "  [Metodo 2] Estrazione EDID da xrandr --verbose (parser python3)..."
        result_bin=$(extract_edid_xrandr "$output")
        if [[ -n "$result_bin" ]]; then
            header=$(xxd "$result_bin" 2>/dev/null | head -1 | awk '{print $2$3}')
            log "  ✓ EDID estratto correttamente (header: $header)"
            log "  Salvato: $(basename "$result_bin")"
            edid_bin="$result_bin"
            EDID_OK=1
        else
            log "  ✗ Nessun blocco EDID hex trovato per $output"
        fi
        ;;

    3)
        # ── METODO 3: hex grezzo da xrandr --verbose ──────────
        # Non produce file .bin né decodifica — logga solo l'hex
        # grezzo per analisi manuale o invio a tool online.
        log ""
        log "  [Metodo 3] Hex grezzo da xrandr --verbose:"
        xrandr --verbose 2>/dev/null | python3 - "$output" << 'PYEOF' | tee -a "$LOG"
import sys, re
target = sys.argv[1]
in_target = False; in_edid = False
for line in sys.stdin:
    m = re.match(r'^(\S+)\s+(connected|disconnected)', line)
    if m:
        in_target = (m.group(1) == target); in_edid = False; continue
    if not in_target: continue
    if re.match(r'^\s+EDID:\s*$', line): in_edid = True; continue
    if in_edid:
        stripped = line.strip()
        if re.match(r'^[0-9a-f]{32}$', stripped): print(stripped)
        else: in_edid = False
PYEOF
        log "  (nessun file .bin generato con metodo 3)"
        ;;

    0)
        log "  Uscita $output saltata dall'utente."
        continue
        ;;

    *)
        warn "Scelta non valida '$metodo_scelta' — uscita $output saltata."
        log "  Scelta non valida — skip"
        continue
        ;;
    esac

    # ── Decodifica se abbiamo un bin valido ───────────────
    if [[ $EDID_OK -eq 1 ]]; then
        log ""
        log "  Decodifica EDID binario..."
        decode_edid_bin "$edid_bin" "$output"
    elif [[ "$metodo_scelta" != "3" && "$metodo_scelta" != "0" ]]; then
        # Il metodo scelto ha fallito — offri subito il metodo 2
        # senza dover rieseguire tutto lo script da capo
        echo ""
        echo -e "${YELLOW}  Il metodo $metodo_scelta non ha prodotto un EDID valido per $output.${NC}"
        if [[ "$metodo_scelta" != "2" ]]; then
            echo -e "  Vuoi tentare il metodo 2 (xrandr --verbose) adesso?"
            read -rp "  [S/n]: " fallback_risposta
            if [[ "${fallback_risposta,,}" != "n" ]]; then
                log "  → Tentativo automatico metodo 2 dopo fallimento metodo $metodo_scelta"
                result_bin=$(extract_edid_xrandr "$output")
                if [[ -n "$result_bin" ]]; then
                    header=$(xxd "$result_bin" 2>/dev/null | head -1 | awk '{print $2$3}')
                    log "  ✓ Metodo 2: EDID estratto correttamente (header: $header)"
                    log "  Salvato: $(basename "$result_bin")"
                    edid_bin="$result_bin"
                    EDID_OK=1
                    decode_edid_bin "$edid_bin" "$output"
                else
                    fail "Nessun metodo ha prodotto un EDID valido per $output"
                    log "  Suggerimento: verifica che il monitor sia acceso e collegato"
                fi
            else
                log "  Fallback metodo 2 rifiutato dall'utente per $output"
                warn "Nessun EDID estratto per $output"
            fi
        else
            fail "Nessun EDID valido ottenuto per $output"
            log "  Suggerimento: verifica che il monitor sia acceso e collegato"
        fi
    fi
    log ""
done
logsep "RIEPILOGO — Cosa inviare per la configurazione"

log "File di log completo: $LOG"
log ""
log "Uscite connesse rilevate:"
for output in $OUTPUTS_CONNECTED; do
    log "  - $output"
done
log ""
log "File generati in questa cartella:"
log "  - $(basename "$LOG")  (log principale)"
log "  - edid-decode_*_${TIMESTAMP}.log  (uno per monitor — analisi completa)"
log "  - parse-edid_*_${TIMESTAMP}.log   (uno per monitor — formato xorg)"
log "  - edid_*_${TIMESTAMP}.bin         (EDID binario grezzo — uno per monitor)"
log ""
log "Per configurare lo script di lancio di Primeval Hunt,"
log "invia tutti i file generati (log + bin)."

echo ""
ok "Raccolta completata."
info "Log principale:  $LOG"
info "File aggiuntivi: edid-decode/parse-edid/bin nella stessa cartella"
echo ""
