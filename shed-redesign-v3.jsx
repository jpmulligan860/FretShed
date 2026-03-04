import { useState, useEffect, useCallback } from "react";

// === WOODSHOP DESIGN SYSTEM ===
const C = {
  bg: "#141210", surface: "#1E1B18", surface2: "#2A2622",
  cherry: "#C4323C", amber: "#D4953A", gold: "#C9A84C", honey: "#B8860B",
  text: "#F5F0E8", text2: "#A89880", muted: "#6B5D4D",
  green: "#4CAF50", red: "#E53935", border: "#3A3530",
  premiumDim: "rgba(168,152,128,0.15)",
  lockBg: "rgba(30,27,24,0.75)",
};
const G = {
  primary: "linear-gradient(135deg, #C4323C, #D4953A)",
  amber: "linear-gradient(135deg, #D4953A, #C9A84C)",
  gold: "linear-gradient(135deg, #C9A84C, #B8860B)",
  premium: "linear-gradient(135deg, #C9A84C, #D4953A)",
};

// === FONTS (inline approximation) ===
const F = {
  mono: "'JetBrains Mono', 'SF Mono', monospace",
  sans: "'Montserrat', system-ui, -apple-system, sans-serif",
  serif: "'Crimson Pro', Georgia, serif",
};

// === SECTION LABEL ===
const SectionLabel = ({ children }) => (
  <div style={{
    fontSize: 10, fontWeight: 600, letterSpacing: 1.5, color: C.text2,
    textTransform: "uppercase", fontFamily: F.mono, marginBottom: 8,
  }}>{children}</div>
);

// === BASELINE OPTIONS ===
const baselineOptions = [
  { id: "total_beginner", title: "Starting Fresh", desc: "I'm pretty new — couldn't tell you what note is where", icon: "🌱",
    priorDetail: "All cells start at 0.50 — maximum uncertainty, system learns from scratch" },
  { id: "chord_player", title: "Chord Player", desc: "I can play songs but couldn't name the notes if you asked me", icon: "🎶",
    priorDetail: "Open strings: 0.75 · Frets 0–3, strings 2–5: 0.60 · Rest: 0.50" },
  { id: "open_position", title: "Open Position", desc: "I know my way around the first few frets", icon: "🎸",
    priorDetail: "Frets 0–4, all strings: 0.70 · Frets 5–12: 0.50" },
  { id: "low_strings", title: "Low Strings Solid", desc: "I know the E and A strings — like finding root notes for barre chords", icon: "🎵",
    priorDetail: "Strings 5–6, all frets: 0.70 · Strings 1–4: 0.50" },
  { id: "rusty_everywhere", title: "Rusty Everywhere", desc: "I used to know more of this stuff, but it's been a while", icon: "🔧",
    priorDetail: "All cells: 0.55 — slightly above uncertain, expects fast improvement" },
];

const generatePriorHeatmap = (id) => {
  const m = Array.from({ length: 6 }, () => Array(13).fill(0.5));
  if (id === "chord_player") {
    for (let s = 0; s < 6; s++) m[s][0] = 0.75;
    for (let s = 1; s < 5; s++) for (let f = 0; f < 4; f++) m[s][f] = 0.6;
  } else if (id === "open_position") {
    for (let s = 0; s < 6; s++) for (let f = 0; f < 5; f++) m[s][f] = 0.7;
  } else if (id === "low_strings") {
    for (let f = 0; f < 13; f++) { m[4][f] = 0.7; m[5][f] = 0.7; }
  } else if (id === "rusty_everywhere") {
    for (let s = 0; s < 6; s++) for (let f = 0; f < 13; f++) m[s][f] = 0.55;
  }
  return m;
};

// === HEATMAP (with freemium boundary) ===
const Heatmap = ({ data, showLabels, showFreemiumBoundary, freeCells }) => {
  const sL = ["e","B","G","D","A","E"];
  const cellW = 21, cellH = 13;
  const getColor = (v) => v <= 0.5 ? C.surface2 : v >= 0.85 ? C.gold : v >= 0.65 ? C.amber : C.cherry;
  const getOp = (v) => v <= 0.5 ? 0.3 : v >= 0.85 ? 1 : v >= 0.65 ? 0.85 : 0.65;

  // Free boundary: strings 3-5 (indices 3,4,5 = D,A,E), frets 0-7
  const isFree = (s, f) => !freeCells || (s >= 3 && f <= 7);

  return (
    <div style={{ display: "flex", gap: 5, alignItems: "center" }}>
      {showLabels && (
        <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
          {sL.map((l,i) => (
            <div key={i} style={{
              height: cellH, display: "flex", alignItems: "center", justifyContent: "flex-end",
              fontSize: 8, color: C.muted, fontFamily: F.mono, width: 12,
            }}>{l}</div>
          ))}
        </div>
      )}
      <div style={{ position: "relative" }}>
        <div style={{
          display: "grid",
          gridTemplateColumns: `repeat(13, ${cellW}px)`,
          gridTemplateRows: `repeat(6, ${cellH}px)`,
          gap: 2, borderRadius: 6, overflow: "hidden",
        }}>
          {data.flat().map((val, i) => {
            const s = Math.floor(i / 13), f = i % 13;
            const free = isFree(s, f);
            return (
              <div key={i} style={{
                width: cellW, height: cellH, borderRadius: 2,
                background: getColor(val), opacity: free ? getOp(val) : getOp(val) * 0.35,
                transition: "all 0.4s ease",
                position: "relative",
              }}>
                {showFreemiumBoundary && !free && (
                  <div style={{
                    position: "absolute", inset: 0, borderRadius: 2,
                    background: "repeating-linear-gradient(45deg, transparent, transparent 2px, rgba(0,0,0,0.15) 2px, rgba(0,0,0,0.15) 4px)",
                  }} />
                )}
              </div>
            );
          })}
        </div>
        {/* Freemium boundary line */}
        {showFreemiumBoundary && (
          <>
            {/* Horizontal line between string 2 (G) and string 3 (D) */}
            <div style={{
              position: "absolute", top: 3 * (cellH + 2) - 1, left: 0,
              width: 8 * (cellW + 2) - 2, height: 1.5,
              borderBottom: `1.5px dashed ${C.amber}`, opacity: 0.6,
            }} />
            {/* Vertical line after fret 7 */}
            <div style={{
              position: "absolute", top: 3 * (cellH + 2), left: 8 * (cellW + 2) - 1,
              width: 1.5, height: 3 * (cellH + 2) - 2,
              borderRight: `1.5px dashed ${C.amber}`, opacity: 0.6,
            }} />
          </>
        )}
      </div>
    </div>
  );
};

// === CALIBRATION PROGRESS BAR ===
const CalibrationProgress = ({ attempts, threshold = 60 }) => {
  const pct = Math.min(100, Math.round((attempts / threshold) * 100));
  const done = pct >= 100;
  return (
    <div style={{
      background: C.surface, borderRadius: 12, padding: "12px 14px",
      marginBottom: 14, border: `1px solid ${done ? C.green : C.border}`,
    }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 6 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <span style={{ fontSize: 14 }}>{done ? "✅" : "🧠"}</span>
          <span style={{ fontSize: 12, fontWeight: 700, color: done ? C.green : C.text }}>
            {done ? "Calibration complete" : "Learning your strengths"}
          </span>
        </div>
        <span style={{
          fontSize: 12, fontWeight: 800, fontFamily: F.mono,
          color: done ? C.green : C.amber,
        }}>{pct}%</span>
      </div>
      <div style={{
        height: 4, borderRadius: 2, background: C.surface2, overflow: "hidden",
      }}>
        <div style={{
          height: "100%", borderRadius: 2, width: `${pct}%`,
          background: done ? C.green : G.primary,
          transition: "width 0.6s ease",
        }} />
      </div>
      {!done && (
        <div style={{ fontSize: 10, color: C.muted, marginTop: 5 }}>
          {threshold - attempts} more answers until your sessions are fully personalized
        </div>
      )}
    </div>
  );
};

// === HALF-SHEET CUSTOMIZER (with freemium locks) ===
const HalfSheet = ({ isOpen, onClose, onStart, isPremium, onPaywall }) => {
  const [focus, setFocus] = useState("full_fretboard");
  const [mode, setMode] = useState("relaxed");
  const [len, setLen] = useState(20);

  const focusModes = [
    { id: "full_fretboard", label: "Full Fretboard", free: true },
    { id: "single_string", label: "Single String", free: true },
    { id: "natural_notes", label: "Natural Notes", free: false },
    { id: "sharps_flats", label: "Sharps & Flats", free: false },
    { id: "fretboard_position", label: "Position", free: false },
    { id: "same_note", label: "Same Note", free: false },
    { id: "chord_prog", label: "Chord Progressions", free: false },
  ];
  const practiceModes = [
    { id: "relaxed", label: "Relaxed" }, { id: "timed", label: "Timed" },
    { id: "tempo", label: "Tempo" }, { id: "streak", label: "Streak" },
  ];

  if (!isOpen) return null;
  return (
    <>
      <div onClick={onClose} style={{
        position: "fixed", inset: 0, background: "rgba(0,0,0,0.55)", zIndex: 90,
      }} />
      <div style={{
        position: "fixed", bottom: 0, left: 0, right: 0, zIndex: 100,
        animation: "slideUp 0.3s cubic-bezier(0.32,0.72,0,1)",
      }}>
        <div style={{
          maxWidth: 420, margin: "0 auto", background: C.surface,
          borderRadius: "20px 20px 0 0", padding: "12px 20px 34px",
          maxHeight: "72vh", overflowY: "auto",
        }}>
          <div style={{ width: 36, height: 5, borderRadius: 3, background: C.border, margin: "0 auto 16px" }} />
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 20 }}>
            <h2 style={{ fontSize: 18, fontWeight: 800, color: C.text, margin: 0 }}>Build Custom Session</h2>
            <button onClick={onClose} style={{
              background: C.surface2, border: "none", borderRadius: "50%",
              width: 30, height: 30, color: C.text2, fontSize: 16, cursor: "pointer",
              display: "flex", alignItems: "center", justifyContent: "center",
            }}>✕</button>
          </div>

          {/* Focus Mode — with locks for free users */}
          <div style={{ marginBottom: 20 }}>
            <SectionLabel>FOCUS</SectionLabel>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
              {focusModes.map((fm) => {
                const locked = !isPremium && !fm.free;
                const selected = focus === fm.id;
                return (
                  <button key={fm.id}
                    onClick={() => {
                      if (locked) { onPaywall(`Unlock "${fm.label}" with FretShed Premium`); return; }
                      setFocus(fm.id);
                    }}
                    style={{
                      padding: "8px 14px", border: "none", borderRadius: 8, cursor: "pointer",
                      background: selected ? C.cherry : locked ? C.surface2 : C.surface2,
                      color: selected ? "white" : locked ? C.muted : C.text2,
                      fontSize: 12, fontWeight: selected ? 700 : 600,
                      fontFamily: F.sans, transition: "all 0.15s ease",
                      display: "flex", alignItems: "center", gap: 5,
                      opacity: locked ? 0.7 : 1,
                    }}
                  >
                    {fm.label}
                    {locked && <span style={{ fontSize: 10, opacity: 0.7 }}>🔒</span>}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Practice Mode */}
          <div style={{ marginBottom: 20 }}>
            <SectionLabel>MODE</SectionLabel>
            <div style={{ display: "flex", gap: 6 }}>
              {practiceModes.map((pm) => (
                <button key={pm.id} onClick={() => setMode(pm.id)} style={{
                  flex: 1, padding: "9px 6px", background: mode === pm.id ? C.cherry : C.surface2,
                  border: "none", borderRadius: 8, color: mode === pm.id ? "white" : C.text2,
                  fontSize: 13, fontWeight: mode === pm.id ? 700 : 600, cursor: "pointer", fontFamily: F.sans,
                }}>{pm.label}</button>
              ))}
            </div>
          </div>

          {/* Length */}
          <div style={{ marginBottom: 24 }}>
            <SectionLabel>LENGTH</SectionLabel>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 24 }}>
              {[{ label: "−", delta: -5 }, null, { label: "+", delta: 5 }].map((btn, i) => {
                if (i === 1) return (
                  <div key="val" style={{ textAlign: "center", minWidth: 60 }}>
                    <div style={{ fontSize: 32, fontWeight: 800, color: C.text, fontFamily: F.mono }}>{len}</div>
                    <div style={{ fontSize: 10, color: C.text2, textTransform: "uppercase", letterSpacing: 1 }}>questions</div>
                  </div>
                );
                return (
                  <button key={btn.label} onClick={() => setLen(Math.max(5, Math.min(50, len + btn.delta)))} style={{
                    width: 40, height: 40, borderRadius: "50%", background: C.surface2,
                    border: `2px solid ${C.border}`, color: C.text, fontSize: 20, fontWeight: 700,
                    cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center",
                  }}>{btn.label}</button>
                );
              })}
            </div>
          </div>

          <button onClick={() => { onStart("custom"); onClose(); }} style={{
            width: "100%", padding: "16px", background: G.primary, border: "none",
            borderRadius: 14, color: "white", fontSize: 15, fontWeight: 800, cursor: "pointer", fontFamily: F.sans,
          }}>Start Custom Session</button>
        </div>
      </div>
    </>
  );
};

// === GRADUATION PAYWALL ===
const GraduationPaywall = ({ onClose, onUpgrade }) => (
  <>
    <div onClick={onClose} style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.6)", zIndex: 90 }} />
    <div style={{
      position: "fixed", bottom: 0, left: 0, right: 0, zIndex: 100,
      animation: "slideUp 0.35s cubic-bezier(0.32,0.72,0,1)",
    }}>
      <div style={{
        maxWidth: 420, margin: "0 auto", background: C.surface,
        borderRadius: "20px 20px 0 0", padding: "20px 24px 34px",
      }}>
        <div style={{ width: 36, height: 5, borderRadius: 3, background: C.border, margin: "0 auto 20px" }} />

        {/* Trophy / celebration */}
        <div style={{ textAlign: "center", marginBottom: 16 }}>
          <div style={{ fontSize: 56, marginBottom: 8 }}>🏆</div>
          <h2 style={{ fontSize: 22, fontWeight: 800, color: C.text, margin: "0 0 4px" }}>
            Root Note Zone Mastered
          </h2>
          <p style={{
            fontSize: 14, color: C.text2, fontFamily: F.serif, fontStyle: "italic", margin: 0,
          }}>
            You've built a strong foundation on the bass strings.
          </p>
        </div>

        {/* Stats */}
        <div style={{
          display: "flex", gap: 8, marginBottom: 20,
        }}>
          {[
            { value: "92%", label: "Mastery" },
            { value: "24/24", label: "Cells" },
            { value: "14", label: "Sessions" },
          ].map((s) => (
            <div key={s.label} style={{
              flex: 1, background: C.surface2, borderRadius: 10, padding: "12px 8px", textAlign: "center",
            }}>
              <div style={{ fontSize: 20, fontWeight: 800, color: C.gold, fontFamily: F.mono }}>{s.value}</div>
              <div style={{ fontSize: 10, color: C.text2, marginTop: 2 }}>{s.label}</div>
            </div>
          ))}
        </div>

        {/* The pitch */}
        <div style={{
          background: "rgba(201,168,76,0.08)", border: `1px solid rgba(201,168,76,0.2)`,
          borderRadius: 14, padding: "16px", marginBottom: 20,
        }}>
          <div style={{ fontSize: 15, fontWeight: 700, color: C.text, marginBottom: 6 }}>
            Ready to learn the treble side?
          </div>
          <div style={{ fontSize: 13, color: C.text2, lineHeight: 1.5, marginBottom: 12 }}>
            You've mastered the D, A, and E strings through fret 7. The full fretboard has
            54 more cells to explore — plus 5 additional practice modes including Chord
            Progressions and Position training.
          </div>
          <div style={{ display: "flex", gap: 12, fontSize: 12, color: C.amber }}>
            <span>🎸 All 6 strings</span>
            <span>🎯 All 12 frets</span>
            <span>⚡ 7 modes</span>
          </div>
        </div>

        {/* Pricing */}
        <div style={{ display: "flex", gap: 8, marginBottom: 16 }}>
          {[
            { period: "Annual", price: "$29.99/yr", perMonth: "$2.50/mo", best: true },
            { period: "Monthly", price: "$4.99/mo", perMonth: "", best: false },
            { period: "Lifetime", price: "$49.99", perMonth: "one time", best: false },
          ].map((p) => (
            <button key={p.period} onClick={onUpgrade} style={{
              flex: 1, padding: "12px 6px", textAlign: "center", cursor: "pointer",
              background: p.best ? "rgba(201,168,76,0.12)" : C.surface2,
              border: `2px solid ${p.best ? C.gold : "transparent"}`,
              borderRadius: 12, position: "relative",
            }}>
              {p.best && (
                <div style={{
                  position: "absolute", top: -8, left: "50%", transform: "translateX(-50%)",
                  background: C.gold, color: C.bg, fontSize: 8, fontWeight: 800,
                  padding: "2px 8px", borderRadius: 4, textTransform: "uppercase", letterSpacing: 1,
                }}>Best Value</div>
              )}
              <div style={{ fontSize: 11, fontWeight: 600, color: C.text2, marginBottom: 4 }}>{p.period}</div>
              <div style={{ fontSize: 15, fontWeight: 800, color: C.text }}>{p.price}</div>
              {p.perMonth && <div style={{ fontSize: 10, color: C.muted, marginTop: 2 }}>{p.perMonth}</div>}
            </button>
          ))}
        </div>

        <button onClick={onUpgrade} style={{
          width: "100%", padding: "16px", background: G.gold, border: "none",
          borderRadius: 14, color: "white", fontSize: 15, fontWeight: 800, cursor: "pointer", fontFamily: F.sans,
          marginBottom: 8,
        }}>Start 14-Day Free Trial</button>

        <button onClick={onClose} style={{
          width: "100%", padding: "12px", background: "none", border: "none",
          color: C.muted, fontSize: 13, cursor: "pointer", fontFamily: F.sans,
        }}>Maybe later</button>
      </div>
    </div>
  </>
);

// === QUIZ PREVIEW (taste of premium) ===
const QuizPreview = ({ onBack }) => {
  const [step, setStep] = useState(0);
  const questions = [
    { string: 5, stringName: "A", note: "C", fret: 3, type: "free", correct: true },
    { string: 4, stringName: "D", note: "F#", fret: 4, type: "free", correct: false, played: "F" },
    { string: 5, stringName: "A", note: "E", fret: 7, type: "free", correct: true },
    { string: 2, stringName: "B", note: "F#", fret: 7, type: "premium", locked: true },
    { string: 4, stringName: "D", note: "A", fret: 7, type: "free", correct: true },
    { string: 1, stringName: "e", note: "G", fret: 3, type: "premium", locked: true },
    { string: 3, stringName: "G", note: "B", fret: 4, type: "free", correct: true },
  ];
  const q = questions[step];
  const total = questions.length;
  const freeCorrect = questions.slice(0, step).filter(q => q.type === "free" && q.correct).length;
  const freeTotal = questions.slice(0, step).filter(q => q.type === "free").length;

  return (
    <div style={{
      minHeight: "100vh", background: C.bg, fontFamily: F.sans,
      maxWidth: 420, margin: "0 auto",
    }}>
      {/* Top bar */}
      <div style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "16px 20px 12px",
      }}>
        <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: C.text }}>
            {freeCorrect}/{freeTotal > 0 ? freeTotal : 0}
          </div>
          <div style={{ fontSize: 12, color: C.text2 }}>
            Q{step + 1}/{total}
          </div>
        </div>
        <div style={{
          fontSize: 10, fontFamily: F.mono, color: C.amber, fontWeight: 600,
          background: "rgba(212,149,58,0.1)", padding: "4px 10px", borderRadius: 6,
        }}>
          Adaptive
        </div>
        <button onClick={onBack} style={{
          background: C.cherry, border: "none", borderRadius: 8,
          color: "white", fontSize: 12, fontWeight: 700, padding: "6px 14px", cursor: "pointer",
        }}>End</button>
      </div>

      {/* Progress bar */}
      <div style={{ padding: "0 20px", marginBottom: 20 }}>
        <div style={{ height: 3, borderRadius: 2, background: C.surface2, overflow: "hidden" }}>
          <div style={{
            height: "100%", borderRadius: 2, width: `${((step + 1) / total) * 100}%`,
            background: G.primary, transition: "width 0.4s ease",
          }} />
        </div>
      </div>

      {/* Question area */}
      <div style={{ padding: "0 20px" }}>
        {q.locked ? (
          // PREMIUM LOCKED QUESTION — taste of premium
          <div style={{
            background: C.surface, borderRadius: 16, padding: "32px 20px",
            textAlign: "center", border: `1px solid rgba(201,168,76,0.25)`,
            position: "relative", overflow: "hidden",
          }}>
            <div style={{
              position: "absolute", inset: 0,
              background: "repeating-linear-gradient(45deg, transparent, transparent 8px, rgba(201,168,76,0.03) 8px, rgba(201,168,76,0.03) 16px)",
            }} />
            <div style={{ position: "relative" }}>
              <div style={{ fontSize: 40, marginBottom: 12 }}>🔒</div>
              <div style={{
                fontSize: 10, fontFamily: F.mono, letterSpacing: 1.5, color: C.gold,
                textTransform: "uppercase", marginBottom: 12,
              }}>
                PREMIUM FRETBOARD AREA
              </div>
              <div style={{ fontSize: 14, color: C.text, fontWeight: 700, marginBottom: 4 }}>
                FretShed wants to test you here:
              </div>
              <div style={{
                fontSize: 32, fontWeight: 800, color: C.gold, marginBottom: 2,
              }}>{q.note}</div>
              <div style={{ fontSize: 14, color: C.text2, marginBottom: 16 }}>
                String {q.string} ({q.stringName}) · Fret {q.fret}
              </div>
              <div style={{
                fontSize: 12, color: C.text2, lineHeight: 1.5, marginBottom: 20,
                maxWidth: 260, margin: "0 auto 20px",
              }}>
                Your adaptive system identified this as a gap in your knowledge. Unlock
                the full fretboard to practice here.
              </div>
              <button style={{
                background: G.gold, border: "none", borderRadius: 12,
                color: "white", fontSize: 13, fontWeight: 800, padding: "12px 24px",
                cursor: "pointer", fontFamily: F.sans, marginBottom: 8,
              }}>
                Unlock Full Fretboard
              </button>
              <br />
              <button onClick={() => setStep(Math.min(total - 1, step + 1))} style={{
                background: "none", border: "none", color: C.muted,
                fontSize: 12, cursor: "pointer", padding: "8px",
              }}>
                Skip for now →
              </button>
            </div>
          </div>
        ) : q.correct === undefined ? (
          // Active question
          <div style={{ textAlign: "center", padding: "40px 0" }}>
            <div style={{
              fontSize: 10, fontFamily: F.mono, letterSpacing: 2, color: C.text2,
              textTransform: "uppercase", marginBottom: 16,
            }}>PLAY THIS NOTE</div>
            <div style={{ fontSize: 18, fontWeight: 700, color: C.amber, marginBottom: 4 }}>
              String {q.string} ({q.stringName})
            </div>
            <div style={{ fontSize: 56, fontWeight: 900, color: C.text }}>{q.note}</div>
          </div>
        ) : (
          // Answered question (showing result)
          <div style={{ textAlign: "center", padding: "20px 0" }}>
            <div style={{
              fontSize: 10, fontFamily: F.mono, letterSpacing: 2, color: C.text2,
              textTransform: "uppercase", marginBottom: 12,
            }}>{q.correct ? "CORRECT" : "WRONG"}</div>
            <div style={{
              background: q.correct ? "rgba(76,175,80,0.12)" : "rgba(229,57,53,0.12)",
              border: `1px solid ${q.correct ? "rgba(76,175,80,0.3)" : "rgba(229,57,53,0.3)"}`,
              borderRadius: 14, padding: "20px", marginBottom: 16,
            }}>
              <div style={{
                fontSize: 42, fontWeight: 900,
                color: q.correct ? C.green : C.red,
              }}>{q.note}</div>
              <div style={{ fontSize: 14, color: C.text2, marginTop: 4 }}>
                String {q.string} ({q.stringName}) · Fret {q.fret}
              </div>
              {!q.correct && (
                <div style={{
                  marginTop: 8, fontSize: 13, color: C.red, fontWeight: 600,
                }}>
                  You played {q.played} — needed {q.note}
                </div>
              )}
            </div>
          </div>
        )}

        {/* Navigation */}
        {!q.locked && (
          <div style={{ display: "flex", gap: 12, marginTop: 20 }}>
            {step > 0 && (
              <button onClick={() => setStep(step - 1)} style={{
                flex: 1, padding: "14px", background: C.surface2, border: "none",
                borderRadius: 12, color: C.text2, fontSize: 13, fontWeight: 600, cursor: "pointer",
              }}>← Previous</button>
            )}
            <button onClick={() => setStep(Math.min(total - 1, step + 1))} style={{
              flex: 2, padding: "14px", background: G.primary, border: "none",
              borderRadius: 12, color: "white", fontSize: 14, fontWeight: 800, cursor: "pointer",
            }}>{step === total - 1 ? "Finish" : "Next →"}</button>
          </div>
        )}
      </div>
    </div>
  );
};

// === SHED PAGE (V3 — all recommendations + freemium) ===
const ShedPage = ({ userState, isPremium, onStartSession, onShowCustomizer, onShowGraduation, onShowQuiz, sessionAttempts }) => {
  const hasHistory = userState !== "new";
  const nearGraduation = userState === "graduating";
  const weakAreas = 14;
  const sessionCount = nearGraduation ? 14 : hasHistory ? 5 : 0;
  const rotationModes = ["Full Fretboard", "Single String (weakest)", "Same Note drill", "Fill the Gaps"];
  const nextMode = rotationModes[sessionCount % rotationModes.length];

  // Heatmap data
  const heatmapData = Array.from({ length: 6 }, (_, s) =>
    Array.from({ length: 13 }, (_, f) => {
      if (!hasHistory) return 0.5;
      // Free area mastered for graduating user
      if (nearGraduation && s >= 3 && f <= 7) return 0.85 + Math.random() * 0.15;
      if (s >= 3 && f <= 7) return 0.55 + Math.random() * 0.35;
      if (f < 3) return 0.5 + Math.random() * 0.3;
      return 0.5 + Math.random() * 0.1;
    })
  );

  // Natural Notes preset options for free users
  const getNaturalNotesOption = () => {
    // Option A: Natural Notes is free
    // Option B: Swap to "Root Notes" which maps to free-tier Full Fretboard
    return { a: true, b: true }; // show both
  };

  const presetsReturning = [
    { id: "weak", label: "Weak Spots", subtitle: `${weakAreas} areas to drill`, icon: "🧠", color: C.cherry, locked: false },
    { id: "gaps", label: "Fill the Gaps", subtitle: "Explore untried cells", icon: "🗺️", color: C.amber, locked: false },
    { id: "repeat", label: "Repeat Last", subtitle: "String 5 (A) · Timed · 85%", icon: "🔄", color: C.gold, locked: false },
  ];

  const presets = hasHistory ? presetsReturning : presetsNew;

  // Timed Practice state
  const [timedMinutes, setTimedMinutes] = useState(5);
  const [timedMode, setTimedMode] = useState("relaxed");
  const [naturalNotesOption, setNaturalNotesOption] = useState("A");
  const timedOptions = [2, 5, 10, 15];
  const timedModes = [
    { id: "relaxed", label: "Relaxed" }, { id: "timed", label: "Per-Note Timer" },
    { id: "streak", label: "Streak" },
  ];

  // Timed Practice component (reused in both new + returning)
  const TimedPractice = () => (
    <div style={{
      background: C.surface, borderRadius: 14, padding: "14px 16px",
      border: `1px solid ${C.border}`, marginBottom: 14,
    }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <span style={{ fontSize: 16 }}>⏱️</span>
          <span style={{ fontSize: 13, fontWeight: 700, color: C.text }}>Timed Practice</span>
        </div>
        <span style={{ fontSize: 10, color: C.muted, fontFamily: F.mono }}>
          adaptive · see how many you can get
        </span>
      </div>
      {/* Time presets */}
      <div style={{ display: "flex", gap: 6, marginBottom: 10 }}>
        {timedOptions.map((min) => (
          <button key={min} onClick={() => setTimedMinutes(min)} style={{
            flex: 1, padding: "10px 4px", textAlign: "center", cursor: "pointer",
            background: timedMinutes === min ? C.cherry : C.surface2,
            border: timedMinutes === min ? `2px solid ${C.cherry}` : `2px solid transparent`,
            borderRadius: 10, transition: "all 0.15s ease",
          }}>
            <div style={{
              fontSize: 18, fontWeight: 800, fontFamily: F.mono,
              color: timedMinutes === min ? "white" : C.text,
            }}>{min}</div>
            <div style={{
              fontSize: 9, color: timedMinutes === min ? "rgba(255,255,255,0.7)" : C.muted,
              textTransform: "uppercase", letterSpacing: 0.5, marginTop: 1,
            }}>min</div>
          </button>
        ))}
      </div>
      {/* Mode selector */}
      <div style={{ display: "flex", gap: 4, marginBottom: 12 }}>
        {timedModes.map((m) => (
          <button key={m.id} onClick={() => setTimedMode(m.id)} style={{
            flex: 1, padding: "6px 4px", fontSize: 11, fontWeight: timedMode === m.id ? 700 : 600,
            background: timedMode === m.id ? "rgba(196,50,60,0.15)" : "transparent",
            border: `1px solid ${timedMode === m.id ? "rgba(196,50,60,0.3)" : C.border}`,
            borderRadius: 6, color: timedMode === m.id ? C.cherry : C.text2,
            cursor: "pointer", fontFamily: F.sans,
          }}>{m.label}</button>
        ))}
      </div>
      {/* Go button */}
      <button onClick={() => onStartSession(`timed_${timedMinutes}min_${timedMode}`)} style={{
        width: "100%", padding: "13px", background: G.primary, border: "none",
        borderRadius: 12, color: "white", fontSize: 14, fontWeight: 800,
        cursor: "pointer", fontFamily: F.sans,
      }}>
        Go — {timedMinutes} Minutes
      </button>
    </div>
  );

  return (
    <div style={{
      minHeight: "100vh", background: C.bg, padding: "20px 20px 100px",
      fontFamily: F.sans, maxWidth: 420, margin: "0 auto",
    }}>
      {/* Header */}
      <div style={{ marginBottom: 16 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
          <div>
            <h1 style={{ fontSize: 24, fontWeight: 800, color: C.text, margin: "0 0 4px" }}>The Shed</h1>
            <p style={{ fontSize: 15, color: C.text2, fontFamily: F.serif, fontStyle: "italic", margin: 0 }}>
              {nearGraduation ? "You've come a long way." : hasHistory ? "Pick up where you left off." : "Time to put in the work."}
            </p>
          </div>
          {!isPremium && (
            <div style={{
              background: "rgba(201,168,76,0.1)", border: `1px solid rgba(201,168,76,0.25)`,
              borderRadius: 8, padding: "4px 10px", fontSize: 10, fontWeight: 700,
              color: C.gold, fontFamily: F.mono, letterSpacing: 0.5,
            }}>FREE</div>
          )}
        </div>
      </div>

      {/* Calibration banner (new users only) */}
      {!hasHistory && (
        <div style={{
          display: "flex", alignItems: "center", gap: 10, padding: "10px 14px",
          background: "rgba(212,149,58,0.08)", border: `1px solid rgba(212,149,58,0.2)`,
          borderRadius: 10, marginBottom: 12,
        }}>
          <span style={{ fontSize: 14 }}>🎤</span>
          <span style={{ fontSize: 12, color: C.amber, fontWeight: 600, flex: 1 }}>
            Audio calibration needed
          </span>
          <button style={{
            background: C.amber, border: "none", borderRadius: 6, color: "white",
            fontSize: 11, fontWeight: 700, padding: "5px 10px", cursor: "pointer", fontFamily: F.sans,
          }}>Set Up</button>
          <button style={{ background: "none", border: "none", color: C.muted, fontSize: 12, cursor: "pointer" }}>✕</button>
        </div>
      )}

      {/* Calibration progress (early returning users) */}
      {hasHistory && !nearGraduation && sessionAttempts < 60 && (
        <CalibrationProgress attempts={sessionAttempts || 25} />
      )}

      {/* Graduation banner (near-graduation users) */}
      {nearGraduation && !isPremium && (
        <button onClick={onShowGraduation} style={{
          width: "100%", padding: "16px", marginBottom: 14, cursor: "pointer",
          background: "rgba(201,168,76,0.08)", border: `1px solid rgba(201,168,76,0.25)`,
          borderRadius: 14, textAlign: "left",
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <span style={{ fontSize: 32 }}>🏆</span>
            <div>
              <div style={{ fontSize: 14, fontWeight: 800, color: C.gold }}>Root Note Zone: 92% Mastered</div>
              <div style={{ fontSize: 12, color: C.text2, marginTop: 2 }}>
                You've outgrown the free fretboard — ready for the next zone?
              </div>
            </div>
            <span style={{ color: C.gold, fontSize: 18, marginLeft: "auto" }}>→</span>
          </div>
        </button>
      )}

      {/* PRIMARY CTA */}
      <button onClick={() => onShowQuiz ? onShowQuiz() : onStartSession("smart")} style={{
        width: "100%", padding: "18px 20px", background: G.primary, border: "none",
        borderRadius: 16, cursor: "pointer", textAlign: "left", position: "relative",
        overflow: "hidden", marginBottom: 14,
      }}>
        <div style={{ position: "absolute", right: -10, top: -10, fontSize: 72, opacity: 0.06 }}>🎸</div>
        <div style={{
          fontSize: 10, fontWeight: 700, letterSpacing: 2, color: "rgba(255,255,255,0.6)",
          textTransform: "uppercase", fontFamily: F.mono, marginBottom: 5,
        }}>
          {hasHistory ? "BASED ON YOUR PROGRESS" : "START HERE"}
        </div>
        <div style={{ fontSize: 20, fontWeight: 800, color: "white", marginBottom: 3 }}>
          {hasHistory ? "Smart Practice" : "Start Practice"}
        </div>
        <div style={{ fontSize: 13, color: "rgba(255,255,255,0.7)" }}>
          {hasHistory
            ? `${nextMode} · adaptive · ${nearGraduation ? "running out of room" : `${weakAreas} weak spots`}`
            : "Adaptive session · Root Note Zone"
          }
        </div>
        {hasHistory && (
          <div style={{ marginTop: 6, fontSize: 9, color: "rgba(255,255,255,0.4)", fontFamily: F.mono }}>
            Rotates: {rotationModes.map((m, i) => (
              <span key={i} style={{
                fontWeight: i === (sessionCount % rotationModes.length) ? 700 : 400,
                color: i === (sessionCount % rotationModes.length) ? "rgba(255,255,255,0.75)" : "rgba(255,255,255,0.3)",
              }}>{i > 0 ? " → " : ""}{m}</span>
            ))}
          </div>
        )}
      </button>

      {/* HEATMAP */}
      {hasHistory && (
        <div style={{
          background: C.surface, borderRadius: 14, padding: "12px 14px", marginBottom: 14,
        }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
            <SectionLabel>YOUR FRETBOARD</SectionLabel>
            <div style={{ display: "flex", gap: 8 }}>
              {[
                { color: C.cherry, label: "Weak" },
                { color: C.amber, label: "Learning" },
                { color: C.gold, label: "Strong" },
              ].map((item) => (
                <div key={item.label} style={{ display: "flex", alignItems: "center", gap: 3 }}>
                  <div style={{ width: 7, height: 7, borderRadius: 2, background: item.color }} />
                  <span style={{ fontSize: 8, color: C.muted }}>{item.label}</span>
                </div>
              ))}
            </div>
          </div>
          <div style={{ display: "flex", justifyContent: "center" }}>
            <Heatmap data={heatmapData} showLabels={true} showFreemiumBoundary={!isPremium} freeCells={true} />
          </div>
          {!isPremium && (
            <div style={{
              fontSize: 10, color: C.muted, textAlign: "center", marginTop: 8,
              fontStyle: "italic",
            }}>
              Hatched area = premium fretboard · Dashed line = your current boundary
            </div>
          )}
        </div>
      )}

      {/* Natural Notes A/B toggle + presets (new user only) */}
      {!hasHistory && (
        <div style={{ marginBottom: 14 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
            <SectionLabel>QUICK START</SectionLabel>
            <div style={{
              display: "flex", background: C.surface2, borderRadius: 6, overflow: "hidden",
            }}>
              {["A", "B"].map((opt) => (
                <button key={opt} onClick={() => setNaturalNotesOption(opt)} style={{
                  padding: "3px 10px", border: "none", cursor: "pointer",
                  background: naturalNotesOption === opt ? C.cherry : "transparent",
                  color: naturalNotesOption === opt ? "white" : C.muted,
                  fontSize: 9, fontWeight: 700, fontFamily: F.mono,
                }}>{opt}</button>
              ))}
            </div>
          </div>

          {/* Option indicator */}
          <div style={{
            fontSize: 10, color: C.muted, marginBottom: 8, fontStyle: "italic",
            background: C.surface, borderRadius: 8, padding: "6px 10px",
          }}>
            {naturalNotesOption === "A"
              ? "Option A: Natural Notes is a free-tier mode (Gavin's recommendation)"
              : "Option B: Natural Notes stays premium — preset swapped to \"Root Notes\" (stays within free modes)"
            }
          </div>

          <div style={{ display: "flex", gap: 8, marginBottom: 14 }}>
            {/* Guided Start */}
            <button onClick={() => onStartSession("guided")} style={{
              flex: 1, padding: "14px 6px", background: C.surface, border: `1px solid ${C.border}`,
              borderRadius: 14, cursor: "pointer", textAlign: "center", minHeight: 100,
              display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 3,
            }}>
              <div style={{ fontSize: 22 }}>🎯</div>
              <div style={{ fontSize: 12, fontWeight: 700, color: C.text }}>Guided Start</div>
              <div style={{ fontSize: 10, color: C.text2 }}>Root note zone</div>
            </button>

            {/* Natural Notes (A) or Root Notes (B) */}
            <button onClick={() => onStartSession(naturalNotesOption === "A" ? "naturals" : "rootnotes")} style={{
              flex: 1, padding: "14px 6px", background: C.surface, border: `1px solid ${C.border}`,
              borderRadius: 14, cursor: "pointer", textAlign: "center", minHeight: 100,
              display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 3,
            }}>
              <div style={{ fontSize: 22 }}>{naturalNotesOption === "A" ? "🎼" : "🎵"}</div>
              <div style={{ fontSize: 12, fontWeight: 700, color: C.text }}>
                {naturalNotesOption === "A" ? "Natural Notes" : "Root Notes"}
              </div>
              <div style={{ fontSize: 10, color: C.text2 }}>
                {naturalNotesOption === "A" ? "A B C D E F G" : "Chord roots, all frets"}
              </div>
            </button>
          </div>

          {/* Timed Practice */}
          <TimedPractice />
        </div>
      )}

      {/* Returning user presets */}
      {hasHistory && (
        <div style={{ marginBottom: 14 }}>
          <SectionLabel>QUICK START</SectionLabel>
          <div style={{ display: "flex", gap: 8 }}>
            {presetsReturning.map((p) => (
              <button key={p.id} onClick={() => onStartSession(p.id)} style={{
                flex: 1, padding: "14px 6px", background: C.surface, border: `1px solid ${C.border}`,
                borderRadius: 14, cursor: "pointer", textAlign: "center", minHeight: 100,
                display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 3,
              }}>
                <div style={{ fontSize: 22 }}>{p.icon}</div>
                <div style={{ fontSize: 12, fontWeight: 700, color: C.text }}>{p.label}</div>
                <div style={{ fontSize: 10, color: C.text2, lineHeight: 1.3 }}>{p.subtitle}</div>
              </button>
            ))}
          </div>
          {/* Timed Practice */}
          <TimedPractice />
        </div>
      )}

      {/* BUILD CUSTOM */}
      <button onClick={onShowCustomizer} style={{
        width: "100%", padding: "14px 16px", background: C.surface,
        border: `1px solid ${C.border}`, borderRadius: 14, cursor: "pointer",
        display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
      }}>
        <span style={{ fontSize: 14 }}>⚙️</span>
        <span style={{ fontSize: 14, fontWeight: 600, color: C.text2 }}>Build Custom Session</span>
      </button>

      <style>{`
        @keyframes slideUp { from { transform: translateY(100%); } to { transform: translateY(0); } }
        @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
      `}</style>
    </div>
  );
};

// === ONBOARDING BASELINE (carried from V2 with minor polish) ===
const OnboardingBaseline = ({ onComplete }) => {
  const [selected, setSelected] = useState(null);
  const opt = baselineOptions.find(o => o.id === selected);
  const hm = selected ? generatePriorHeatmap(selected) : null;

  return (
    <div style={{
      minHeight: "100vh", background: C.bg, padding: "24px 20px",
      fontFamily: F.sans, maxWidth: 420, margin: "0 auto",
    }}>
      <div style={{ textAlign: "center", marginBottom: 24 }}>
        <SectionLabel>GETTING STARTED</SectionLabel>
        <h1 style={{ fontSize: 24, fontWeight: 800, color: C.text, margin: "0 0 8px" }}>Where are you at?</h1>
        <p style={{ fontSize: 15, color: C.text2, fontFamily: F.serif, fontStyle: "italic", margin: 0, lineHeight: 1.4 }}>
          This helps FretShed focus your practice on what you actually need.
        </p>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 7 }}>
        {baselineOptions.map((o) => (
          <button key={o.id} onClick={() => setSelected(o.id)} style={{
            display: "flex", alignItems: "center", gap: 12, padding: "12px 13px",
            background: selected === o.id ? "rgba(196,50,60,0.12)" : C.surface,
            border: `2px solid ${selected === o.id ? C.cherry : "transparent"}`,
            borderRadius: 14, cursor: "pointer", textAlign: "left",
            transition: "all 0.2s ease",
          }}>
            <div style={{
              fontSize: 24, width: 40, height: 40, display: "flex", alignItems: "center",
              justifyContent: "center", background: C.surface2, borderRadius: 10, flexShrink: 0,
            }}>{o.icon}</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 700, color: C.text, marginBottom: 1 }}>{o.title}</div>
              <div style={{ fontSize: 12, color: C.text2, lineHeight: 1.3 }}>{o.desc}</div>
            </div>
            {selected === o.id && (
              <div style={{
                width: 20, height: 20, borderRadius: "50%", background: G.primary,
                display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
                fontSize: 11, color: "white",
              }}>✓</div>
            )}
          </button>
        ))}
      </div>

      {selected && hm && (
        <div style={{
          marginTop: 14, background: C.surface, borderRadius: 14, padding: "12px 14px",
          animation: "fadeIn 0.3s ease",
        }}>
          <SectionLabel>HOW WE'LL START YOU</SectionLabel>
          <div style={{ fontSize: 11, color: C.muted, marginBottom: 10, lineHeight: 1.4 }}>{opt?.priorDetail}</div>
          <div style={{ display: "flex", justifyContent: "center" }}>
            <Heatmap data={hm} showLabels={true} showFreemiumBoundary={false} />
          </div>
        </div>
      )}

      <p style={{ fontSize: 11, color: C.muted, textAlign: "center", margin: "14px 0", lineHeight: 1.5 }}>
        Don't worry about getting it perfect — FretShed adapts as you play.
      </p>

      <button onClick={() => selected && onComplete(selected)} disabled={!selected} style={{
        width: "100%", padding: "16px", background: selected ? G.primary : C.surface2,
        border: "none", borderRadius: 14, color: selected ? "white" : C.muted,
        fontSize: 15, fontWeight: 800, cursor: selected ? "pointer" : "default",
        fontFamily: F.sans, opacity: selected ? 1 : 0.6,
      }}>Continue</button>
    </div>
  );
};

// === MAIN APP ===
export default function ShedV3() {
  const [screen, setScreen] = useState("switcher");
  const [toast, setToast] = useState(null);
  const [showCustomizer, setShowCustomizer] = useState(false);
  const [showGraduation, setShowGraduation] = useState(false);

  const flash = (msg) => { setToast(msg); setTimeout(() => setToast(null), 2500); };

  const screens = [
    { id: "onboarding", title: "1. Onboarding Baseline", desc: "Chord Player option + Bayesian prior preview", icon: "🌱" },
    { id: "shed_free_new", title: "2. Shed — Free, New User", desc: "Calibration banner, Natural Notes A/B toggle, Quick 5", icon: "🆕" },
    { id: "shed_free_returning", title: "3. Shed — Free, Returning", desc: "Calibration progress, heatmap with freemium boundary, Fill the Gaps", icon: "📊" },
    { id: "shed_graduating", title: "4. Shed — Free, Graduating", desc: "Root Note Zone mastered, graduation paywall trigger", icon: "🏆" },
    { id: "quiz_preview", title: "5. Quiz — Taste of Premium", desc: "Smart Practice session with locked premium questions", icon: "🔒" },
    { id: "half_sheet", title: "6. Half-Sheet Customizer", desc: "Locked focus modes with lock icons for free users", icon: "⚙️" },
  ];

  return (
    <div style={{ background: "#0A0908", minHeight: "100vh", fontFamily: F.sans }}>
      {/* Toast */}
      {toast && (
        <div style={{
          position: "fixed", top: 20, left: "50%", transform: "translateX(-50%)",
          background: C.surface, border: `1px solid ${C.amber}`, borderRadius: 12,
          padding: "12px 20px", color: C.text, fontSize: 13, fontWeight: 600,
          zIndex: 300, boxShadow: "0 8px 32px rgba(0,0,0,0.5)", maxWidth: "90%", textAlign: "center",
        }}>{toast}</div>
      )}

      {/* Graduation paywall overlay */}
      {showGraduation && (
        <GraduationPaywall
          onClose={() => setShowGraduation(false)}
          onUpgrade={() => { setShowGraduation(false); flash("Trial started! Full fretboard unlocked."); }}
        />
      )}

      {/* Customizer overlay */}
      {showCustomizer && (
        <HalfSheet
          isOpen={true}
          onClose={() => setShowCustomizer(false)}
          onStart={(type) => { flash(`Custom session started: ${type}`); setShowCustomizer(false); }}
          isPremium={false}
          onPaywall={(msg) => flash(`🔒 ${msg}`)}
        />
      )}

      {/* Switcher */}
      {screen === "switcher" && (
        <div style={{ maxWidth: 420, margin: "0 auto", padding: "32px 20px" }}>
          <div style={{ textAlign: "center", marginBottom: 6 }}>
            <div style={{
              fontSize: 10, fontWeight: 700, letterSpacing: 2, color: C.cherry,
              textTransform: "uppercase", fontFamily: F.mono, marginBottom: 6,
            }}>V3 — ALL RECOMMENDATIONS + FREEMIUM</div>
            <h1 style={{ fontSize: 22, fontWeight: 800, color: C.text, margin: "0 0 6px" }}>Shed Page Redesign</h1>
            <p style={{ fontSize: 13, color: C.text2, fontFamily: F.serif, fontStyle: "italic", margin: "0 0 4px" }}>
              Complete mockup with expert recommendations and freemium layer
            </p>
          </div>

          {/* Summary */}
          <div style={{
            background: C.surface, borderRadius: 12, padding: "12px 14px", marginBottom: 16, fontSize: 11,
          }}>
            <SectionLabel>WHAT'S NEW IN V3</SectionLabel>
            {[
              "Freemium boundary on heatmap (dashed line + hatched premium cells)",
              "Half-sheet customizer with locked premium focus modes",
              "\"Taste of premium\" locked questions in Smart Practice quiz",
              "\"Root Note Zone Mastered\" graduation paywall",
              "\"Fill the Gaps\" preset for returning users",
              "\"Timed Practice\" replaces Quick 5 — pick 2/5/10/15 min, see how many you get",
              "Timed Practice with mode picker (Relaxed / Per-Note Timer / Streak)",
              "Calibration progress bar (\"Learning your strengths — 42%\")",
              "Natural Notes A/B toggle (free-tier vs. premium)",
              "\"Repeat Last\" with accuracy score from previous session",
              "FREE badge on Shed page header for free users",
            ].map((c, i) => (
              <div key={i} style={{ color: C.text2, padding: "2px 0", lineHeight: 1.4 }}>✅ {c}</div>
            ))}
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {screens.map((s) => (
              <button key={s.id} onClick={() => setScreen(s.id)} style={{
                display: "flex", alignItems: "center", gap: 12, padding: "16px 14px",
                background: C.surface, border: `1px solid ${C.border}`, borderRadius: 14,
                cursor: "pointer", textAlign: "left",
              }}>
                <div style={{
                  fontSize: 28, width: 48, height: 48, display: "flex", alignItems: "center",
                  justifyContent: "center", background: C.surface2, borderRadius: 10, flexShrink: 0,
                }}>{s.icon}</div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 15, fontWeight: 700, color: C.text, marginBottom: 2 }}>{s.title}</div>
                  <div style={{ fontSize: 12, color: C.text2, lineHeight: 1.3 }}>{s.desc}</div>
                </div>
                <span style={{ color: C.text2, fontSize: 18 }}>→</span>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Back */}
      {screen !== "switcher" && (
        <div style={{ maxWidth: 420, margin: "0 auto", padding: "12px 20px 0" }}>
          <button onClick={() => { setScreen("switcher"); setShowCustomizer(false); setShowGraduation(false); }} style={{
            background: "none", border: "none", color: C.amber, fontSize: 14,
            fontWeight: 600, cursor: "pointer", padding: "8px 0", fontFamily: F.sans,
          }}>← Back to Overview</button>
        </div>
      )}

      {/* Screens */}
      {screen === "onboarding" && (
        <OnboardingBaseline onComplete={(lvl) => {
          flash(`Baseline: "${baselineOptions.find(o => o.id === lvl)?.title}" — priors seeded`);
          setTimeout(() => setScreen("shed_free_new"), 1500);
        }} />
      )}

      {screen === "shed_free_new" && (
        <ShedPage
          userState="new" isPremium={false} sessionAttempts={0}
          onStartSession={(t) => flash(`Session: ${t}`)}
          onShowCustomizer={() => setShowCustomizer(true)}
        />
      )}

      {screen === "shed_free_returning" && (
        <ShedPage
          userState="returning" isPremium={false} sessionAttempts={25}
          onStartSession={(t) => flash(`Session: ${t}`)}
          onShowCustomizer={() => setShowCustomizer(true)}
        />
      )}

      {screen === "shed_graduating" && (
        <ShedPage
          userState="graduating" isPremium={false} sessionAttempts={85}
          onStartSession={(t) => flash(`Session: ${t}`)}
          onShowCustomizer={() => setShowCustomizer(true)}
          onShowGraduation={() => setShowGraduation(true)}
        />
      )}

      {screen === "quiz_preview" && (
        <QuizPreview onBack={() => setScreen("switcher")} />
      )}

      {screen === "half_sheet" && (
        <div>
          <ShedPage
            userState="returning" isPremium={false} sessionAttempts={40}
            onStartSession={(t) => flash(`Session: ${t}`)}
            onShowCustomizer={() => setShowCustomizer(true)}
          />
          {/* Auto-open the customizer for this screen */}
          {!showCustomizer && (
            <div style={{
              maxWidth: 420, margin: "0 auto", padding: "0 20px",
            }}>
              <button onClick={() => setShowCustomizer(true)} style={{
                width: "100%", padding: "14px", background: G.amber, border: "none",
                borderRadius: 14, color: "white", fontSize: 14, fontWeight: 800,
                cursor: "pointer", fontFamily: F.sans,
              }}>
                Tap to open the half-sheet customizer ↑
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
