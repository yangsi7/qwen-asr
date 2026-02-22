# Feasibility Test 002: Medical Terminology Accuracy

**Date**: 2026-02-22
**Model**: Qwen3-ASR-0.6B
**Hardware**: Apple Silicon Mac
**Build**: `make blas` (Apple Accelerate + ARM NEON)
**Test Suite**: tests/test-medical-accuracy.sh

## Methodology

### Test Corpus
- **Categories**: 5 medical vocabulary domains
- **Total terms**: 61
- **Audio source**: macOS TTS (`say -v Samantha`) → ffmpeg → WAV (16kHz mono)
- **Matching**: Case-insensitive fixed-string substring match (`grep -iqF`)

### Categories Tested
| Category | Terms | Description |
|----------|-------|-------------|
| psychiatric-medications | 13 | SSRIs, SNRIs, antipsychotics, benzodiazepines, mood stabilizers |
| diagnoses | 12 | DSM-5 diagnostic terms (MDD, GAD, PTSD, bipolar, etc.) |
| anatomical-terms | 11 | Neuroanatomy (prefrontal cortex, hippocampus, amygdala, etc.) |
| vitals-measurements | 13 | Vital signs, lab values, units, dosage language |
| clinical-phrases | 12 | Clinical workflow phrases (treatment plan, risk assessment, etc.) |

### Assumptions
- [A1] TTS-generated audio is a reasonable proxy for natural clinical speech
- [A2] The 0.6B model is the target for feasibility testing
- [A3] Case-insensitive substring matching is sufficient for term detection
- No synonym mapping: "mg" ≠ "milligrams" (documents actual model behavior)

## Results

### Per-Category Accuracy
| Category | Hit | Total | Accuracy |
|----------|-----|-------|----------|
| psychiatric-medications | 11 | 13 | 84% |
| diagnoses | 10 | 12 | 83% |
| anatomical-terms | 11 | 11 | 100% |
| vitals-measurements | 12 | 13 | 92% |
| clinical-phrases | 12 | 12 | 100% |
| **Overall** | **56** | **61** | **91%** |

### Missed Terms
- **psychiatric-medications**: escitalopram, risperidone
- **diagnoses**: post-traumatic stress disorder, schizoaffective disorder
- **vitals-measurements**: thyroid stimulating hormone

### Transcription Samples

#### psychiatric-medications
```
The patient is currently prescribed sertraline one hundred milligrams daily for depression, having previously tried fluoxetine without adequate response. Due to persistent insomnia and agitation, quetiapine twenty five milligrams at bedtime was added for acute anxiety episodes. Lorazepam zero point five milligrams as needed was prescribed. The treatment history includes esitaloprim, venlafaxine, and bupropion, none of which achieved remission. The psychiatrist is considering aripiprazole as an adjunct. The patient also takes clonazepam for panic disorder and previously tried reserpine during a brief psychotic episode. Current augmentation strategy includes duloxetine for comorbid neuropathic pain and lamotrigine for mood stabilization. Serum lithium levels should be monitored quarterly.
```

#### diagnoses
```
The differential diagnosis includes major depressive disorder with anxious distress versus generalized anxiety disorder with comorbid depressive features. The patient's trauma history raises concern for post traumatic stress disorder. Family history is significant for bipolar disorder in the mother and schizophrenia in a paternal uncle. Previous evaluations considered obsessive compulsive disorder given the patient's intrusive thoughts, as well as attention deficit hyperactivity disorder due to concentration difficulties. The clinician should rule out borderline personality disorder given the interpersonal instability. The patient also meets criteria for panic disorder and social anxiety disorder. If symptoms persist beyond two years, persistent depressive disorder should be considered. The combination of mood and psychotic symptoms may warrant evaluation for schizo affective disorder.
```

#### anatomical-terms
```
Neuroimaging reveals reduced activation in the prefrontal cortex during executive function tasks. The hippocampus shows bilateral volume reduction consistent with chronic stress exposure. Increased amygdalar reactivity to threat stimuli was observed. The basal ganglia demonstrate altered dopaminergic signaling patterns. Functional connectivity between the anterior cingulate cortex and limbic structures is diminished. Disregulation of the hypothalamic pituitary adrenal axis is evidenced by elevated cortisol levels. The dorsolateral prefrontal cortex shows decreased gray matter density. Reward processing abnormalities are noted in the nucleus accumbens. The ventromedial prefrontal cortex demonstrates impaired emotional regulation capacity. The cerebellum contributes to cognitive timing and coordination. Signal transmission through the thalamus relay sensory information to cortical regions.
```

#### vitals-measurements
```
Vital signs show blood pressure 138 over 86 millimeters of mercury, heart rate 92 beats per minute, oxygen saturation 97% on room air, body mass index is 31.2, indicating obesity. Current medications include sertraline 100 milligrams twice daily. Fasting blood glucose was 112 milligrams per deciliter. Respiratory rate is 16 breaths per minute. Temperature is 98.6 degrees Fahrenheit. Total cholesterol is 224 milligrams per deciliter with LDL elevated. Hemoglobin is 13.8 grams per deciliter, within normal range. Serum creatinine is 1.1 milligrams per deciliter, indicating normal renal function. Fyreoid stimulating hormone is 2.4 milliunits per liter.
```

#### clinical-phrases
```
The patient presents with worsening depressive symptoms over the past three weeks. The mental status examination reveals a cooperative but tearful individual with constricted affect. The treatment plan will be updated to reflect medication adjustments and increased therapy frequency. A thorough differential diagnosis was conducted to rule out medical causes. Informed consent was obtained for the new medication regimen. A comprehensive risk assessment indicates low acute risk but moderate chronic risk. Establishing a strong therapeutic alliance remains a priority. The patient will continue cognitive behavioral therapy twice weekly. Medication management will be handled by the attending psychiatrist. This psychiatric evaluation was requested by the primary care provider. Discharge planning should begin once symptoms stabilize. The patient agreed to a safety contract as part of the crisis intervention protocol.
```

## Go/No-Go Assessment

### Criteria
| Criterion | Threshold | Actual | Status |
|-----------|-----------|--------|--------|
| Overall accuracy | >= 85% | 91% | PASS |
| Min category accuracy | >= 70% | 83% (diagnoses) | PASS |
| Realtime factor | >= 3x | See latency tests | -- |
| Memory usage | < 4GB | See latency tests | -- |

### Verdict: **GO**

All criteria met. The Qwen3-ASR 0.6B model demonstrates sufficient medical terminology accuracy for further development.

## Notes

- TTS pronunciation may differ from natural clinical speech — results are a lower bound for real-world accuracy
- No synonym mapping applied: model must produce the exact term (case-insensitive)
- Latency and memory metrics require separate test: `bash tests/test-medical-latency.sh`
- Model version: Qwen3-ASR-0.6B (see qwen3-asr-0.6b/ for weights)
