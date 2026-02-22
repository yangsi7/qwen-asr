#!/usr/bin/env bash
# Medical terminology accuracy test for qwen-asr
# Tests transcription accuracy across 5 medical vocabulary categories (61 terms)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY="$PROJECT_DIR/qwen_asr"
MODEL_DIR="$PROJECT_DIR/qwen3-asr-0.6b"
AUDIO_DIR="$SCRIPT_DIR/medical-audio"
REPORT_FILE="$PROJECT_DIR/docs/feasibility/002-medical-terminology-test.md"

GENERATE_REPORT=0
CATEGORIES=(psychiatric-medications diagnoses anatomical-terms vitals-measurements clinical-phrases)

usage() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Tests qwen-asr transcription accuracy on medical terminology."
    echo "Runs 5 category tests (61 terms total) and reports per-category + overall accuracy."
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help text"
    echo "  --report       Generate feasibility report to docs/feasibility/"
    echo ""
    echo "Prerequisites:"
    echo "  - qwen_asr binary (make blas)"
    echo "  - qwen3-asr-0.6b model directory"
    echo "  - WAV files in tests/medical-audio/ (run scripts/generate-medical-test-audio.sh)"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        --report) GENERATE_REPORT=1; shift ;;
        *) echo "Error: Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Prerequisites
echo "=== Medical Terminology Accuracy Test ==="
echo ""
echo "[Prerequisites]"

PREREQ_FAIL=0
for prereq_name in "binary:$BINARY" "model:$MODEL_DIR/vocab.json"; do
    label="${prereq_name%%:*}"
    path="${prereq_name#*:}"
    if [[ -e "$path" ]]; then
        echo "  PASS: $label exists"
    else
        echo "  FAIL: $label not found at $path"
        PREREQ_FAIL=1
    fi
done

if ! command -v ffmpeg &>/dev/null; then
    echo "  FAIL: ffmpeg not found"
    PREREQ_FAIL=1
else
    echo "  PASS: ffmpeg available"
fi

# Check WAV files exist
MISSING_WAV=0
for cat in "${CATEGORIES[@]}"; do
    if [[ ! -f "$AUDIO_DIR/${cat}.wav" ]]; then
        echo "  FAIL: $AUDIO_DIR/${cat}.wav not found"
        MISSING_WAV=1
    fi
done
if [[ "$MISSING_WAV" -eq 1 ]]; then
    echo ""
    echo "  Missing WAV files. Run: bash scripts/generate-medical-test-audio.sh"
    PREREQ_FAIL=1
else
    echo "  PASS: all category WAV files present"
fi

if [[ "$PREREQ_FAIL" -eq 1 ]]; then
    echo ""
    echo "Prerequisites failed. Aborting."
    exit 1
fi

# Run accuracy tests per category
TOTAL_HIT=0
TOTAL_MISS=0
TOTAL_TERMS=0

# Arrays to collect per-category results for report
declare -a CAT_NAMES=()
declare -a CAT_HITS=()
declare -a CAT_TOTALS=()
declare -a CAT_PCTS=()
declare -a CAT_MISSED_TERMS=()
declare -a CAT_TRANSCRIPTS=()

for cat in "${CATEGORIES[@]}"; do
    echo ""
    echo "[$cat]"

    WAV_FILE="$AUDIO_DIR/${cat}.wav"
    TERMS_FILE="$AUDIO_DIR/${cat}.terms.txt"

    if [[ ! -f "$TERMS_FILE" ]]; then
        echo "  SKIP: no terms file"
        continue
    fi

    # Transcribe
    echo "  Transcribing ${cat}.wav ..."
    TRANSCRIPT=$("$BINARY" -d "$MODEL_DIR" -i "$WAV_FILE" --silent 2>/dev/null || true)

    if [[ -z "$TRANSCRIPT" ]]; then
        echo "  FAIL: Empty transcription"
        # Count all terms as misses
        TERM_COUNT=$(wc -l < "$TERMS_FILE" | tr -d ' ')
        TOTAL_MISS=$((TOTAL_MISS + TERM_COUNT))
        TOTAL_TERMS=$((TOTAL_TERMS + TERM_COUNT))
        CAT_NAMES+=("$cat")
        CAT_HITS+=(0)
        CAT_TOTALS+=("$TERM_COUNT")
        CAT_PCTS+=("0")
        CAT_MISSED_TERMS+=("(all terms)")
        CAT_TRANSCRIPTS+=("(empty)")
        continue
    fi

    CAT_TRANSCRIPTS+=("$TRANSCRIPT")

    # Match terms
    CAT_HIT=0
    CAT_TOTAL=0
    MISSED=""

    while IFS= read -r term; do
        [[ -z "$term" ]] && continue
        CAT_TOTAL=$((CAT_TOTAL + 1))

        if echo "$TRANSCRIPT" | grep -iqF "$term"; then
            echo "    HIT:  $term"
            CAT_HIT=$((CAT_HIT + 1))
        else
            echo "    MISS: $term"
            if [[ -n "$MISSED" ]]; then
                MISSED="$MISSED, $term"
            else
                MISSED="$term"
            fi
        fi
    done < "$TERMS_FILE"

    # Per-category summary
    if [[ "$CAT_TOTAL" -gt 0 ]]; then
        PCT=$((CAT_HIT * 100 / CAT_TOTAL))
    else
        PCT=0
    fi
    echo "  Result: $CAT_HIT/$CAT_TOTAL ($PCT%)"

    TOTAL_HIT=$((TOTAL_HIT + CAT_HIT))
    TOTAL_MISS=$((TOTAL_MISS + (CAT_TOTAL - CAT_HIT)))
    TOTAL_TERMS=$((TOTAL_TERMS + CAT_TOTAL))

    CAT_NAMES+=("$cat")
    CAT_HITS+=("$CAT_HIT")
    CAT_TOTALS+=("$CAT_TOTAL")
    CAT_PCTS+=("$PCT")
    CAT_MISSED_TERMS+=("$MISSED")
done

# Overall summary
echo ""
echo "=== Overall Results ==="
if [[ "$TOTAL_TERMS" -gt 0 ]]; then
    OVERALL_PCT=$((TOTAL_HIT * 100 / TOTAL_TERMS))
else
    OVERALL_PCT=0
fi

echo ""
printf "  %-30s %s\n" "Category" "Accuracy"
printf "  %-30s %s\n" "--------" "--------"
for i in "${!CAT_NAMES[@]}"; do
    printf "  %-30s %s/%s (%s%%)\n" "${CAT_NAMES[$i]}" "${CAT_HITS[$i]}" "${CAT_TOTALS[$i]}" "${CAT_PCTS[$i]}"
done
printf "  %-30s %s\n" "--------" "--------"
printf "  %-30s %s/%s (%s%%)\n" "OVERALL" "$TOTAL_HIT" "$TOTAL_TERMS" "$OVERALL_PCT"

# Go/No-Go assessment
echo ""
echo "=== Go/No-Go Assessment ==="
GO=1

if [[ "$OVERALL_PCT" -ge 85 ]]; then
    echo "  PASS: Overall accuracy >= 85% ($OVERALL_PCT%)"
else
    echo "  FAIL: Overall accuracy < 85% ($OVERALL_PCT%)"
    GO=0
fi

MIN_CAT_PCT=100
MIN_CAT_NAME=""
for i in "${!CAT_PCTS[@]}"; do
    if [[ "${CAT_PCTS[$i]}" -lt "$MIN_CAT_PCT" ]]; then
        MIN_CAT_PCT="${CAT_PCTS[$i]}"
        MIN_CAT_NAME="${CAT_NAMES[$i]}"
    fi
done

if [[ "$MIN_CAT_PCT" -ge 70 ]]; then
    echo "  PASS: Minimum category accuracy >= 70% ($MIN_CAT_NAME: $MIN_CAT_PCT%)"
else
    echo "  FAIL: Category below 70% ($MIN_CAT_NAME: $MIN_CAT_PCT%)"
    GO=0
fi

if [[ "$GO" -eq 1 ]]; then
    echo ""
    echo "  VERDICT: GO"
else
    echo ""
    echo "  VERDICT: NO-GO (see failed criteria above)"
fi

# Generate report if requested
if [[ "$GENERATE_REPORT" -eq 1 ]]; then
    echo ""
    echo "=== Generating Feasibility Report ==="

    mkdir -p "$(dirname "$REPORT_FILE")"

    cat > "$REPORT_FILE" << REPORT_EOF
# Feasibility Test 002: Medical Terminology Accuracy

**Date**: $(date +%Y-%m-%d)
**Model**: Qwen3-ASR-0.6B
**Hardware**: Apple Silicon Mac
**Build**: \`make blas\` (Apple Accelerate + ARM NEON)
**Test Suite**: tests/test-medical-accuracy.sh

## Methodology

### Test Corpus
- **Categories**: 5 medical vocabulary domains
- **Total terms**: $TOTAL_TERMS
- **Audio source**: macOS TTS (\`say -v Samantha\`) → ffmpeg → WAV (16kHz mono)
- **Matching**: Case-insensitive fixed-string substring match (\`grep -iqF\`)

### Categories Tested
| Category | Terms | Description |
|----------|-------|-------------|
| psychiatric-medications | ${CAT_TOTALS[0]:-0} | SSRIs, SNRIs, antipsychotics, benzodiazepines, mood stabilizers |
| diagnoses | ${CAT_TOTALS[1]:-0} | DSM-5 diagnostic terms (MDD, GAD, PTSD, bipolar, etc.) |
| anatomical-terms | ${CAT_TOTALS[2]:-0} | Neuroanatomy (prefrontal cortex, hippocampus, amygdala, etc.) |
| vitals-measurements | ${CAT_TOTALS[3]:-0} | Vital signs, lab values, units, dosage language |
| clinical-phrases | ${CAT_TOTALS[4]:-0} | Clinical workflow phrases (treatment plan, risk assessment, etc.) |

### Assumptions
- [A1] TTS-generated audio is a reasonable proxy for natural clinical speech
- [A2] The 0.6B model is the target for feasibility testing
- [A3] Case-insensitive substring matching is sufficient for term detection
- No synonym mapping: "mg" ≠ "milligrams" (documents actual model behavior)

## Results

### Per-Category Accuracy
| Category | Hit | Total | Accuracy |
|----------|-----|-------|----------|
REPORT_EOF

    for i in "${!CAT_NAMES[@]}"; do
        echo "| ${CAT_NAMES[$i]} | ${CAT_HITS[$i]} | ${CAT_TOTALS[$i]} | ${CAT_PCTS[$i]}% |" >> "$REPORT_FILE"
    done

    cat >> "$REPORT_FILE" << REPORT_EOF2
| **Overall** | **$TOTAL_HIT** | **$TOTAL_TERMS** | **${OVERALL_PCT}%** |

### Missed Terms
REPORT_EOF2

    for i in "${!CAT_NAMES[@]}"; do
        if [[ -n "${CAT_MISSED_TERMS[$i]}" ]]; then
            echo "- **${CAT_NAMES[$i]}**: ${CAT_MISSED_TERMS[$i]}" >> "$REPORT_FILE"
        fi
    done

    HAS_MISSES=0
    for i in "${!CAT_MISSED_TERMS[@]}"; do
        if [[ -n "${CAT_MISSED_TERMS[$i]}" ]]; then
            HAS_MISSES=1
            break
        fi
    done
    if [[ "$HAS_MISSES" -eq 0 ]]; then
        echo "None — all terms detected." >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << REPORT_EOF3

### Transcription Samples
REPORT_EOF3

    for i in "${!CAT_NAMES[@]}"; do
        {
            echo ""
            echo "#### ${CAT_NAMES[$i]}"
            echo '```'
            echo "${CAT_TRANSCRIPTS[$i]}"
            echo '```'
        } >> "$REPORT_FILE"
    done

    if [[ "$GO" -eq 1 ]]; then
        VERDICT_TEXT="GO"
        VERDICT_DETAIL="All criteria met. The Qwen3-ASR 0.6B model demonstrates sufficient medical terminology accuracy for further development."
    else
        VERDICT_TEXT="NO-GO"
        VERDICT_DETAIL="One or more criteria failed. Review per-category results and missed terms before proceeding."
    fi

    cat >> "$REPORT_FILE" << REPORT_EOF4

## Go/No-Go Assessment

### Criteria
| Criterion | Threshold | Actual | Status |
|-----------|-----------|--------|--------|
| Overall accuracy | >= 85% | ${OVERALL_PCT}% | $(if [[ "$OVERALL_PCT" -ge 85 ]]; then echo "PASS"; else echo "FAIL"; fi) |
| Min category accuracy | >= 70% | ${MIN_CAT_PCT}% ($MIN_CAT_NAME) | $(if [[ "$MIN_CAT_PCT" -ge 70 ]]; then echo "PASS"; else echo "FAIL"; fi) |
| Realtime factor | >= 3x | See latency tests | -- |
| Memory usage | < 4GB | See latency tests | -- |

### Verdict: **$VERDICT_TEXT**

$VERDICT_DETAIL

## Notes

- TTS pronunciation may differ from natural clinical speech — results are a lower bound for real-world accuracy
- No synonym mapping applied: model must produce the exact term (case-insensitive)
- Latency and memory metrics require separate test: \`bash tests/test-medical-latency.sh\`
- Model version: Qwen3-ASR-0.6B (see qwen3-asr-0.6b/ for weights)
REPORT_EOF4

    echo "  Report written to: $REPORT_FILE"
fi

echo ""
echo "=== Results: $TOTAL_HIT/$TOTAL_TERMS terms matched ($OVERALL_PCT%) ==="
[[ "$GO" -eq 1 ]] && exit 0 || exit 1
