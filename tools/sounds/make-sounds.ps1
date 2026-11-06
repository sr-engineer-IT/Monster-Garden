# Generates the Moonlit Grove sound effects and music loops as .wav files (no recording, pure code).
# Output: Resources\Sounds\*.wav  -> upload to Roblox (Creator Dashboard > Development items > Audio,
# or Studio > Asset Manager > Bulk Import), then put the IDs into src\config\Sounds.luau.
# Run: powershell -ExecutionPolicy Bypass -File tools\sounds\make-sounds.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out = Join-Path $root "Resources\Sounds"
New-Item -ItemType Directory -Force $out | Out-Null

Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.IO;

public static class Synth {
	public const int Rate = 44100;
	static Random rng = new Random(7);

	public static float[] Buf(double seconds) { return new float[(int)(seconds * Rate)]; }

	public static double Note(int midi) { return 440.0 * Math.Pow(2.0, (midi - 69) / 12.0); }

	// waveforms: 0 sine, 1 triangle, 2 soft square, 3 saw, 4 bell (inharmonic partials)
	static double Wave(int kind, double phase) {
		double s = Math.Sin(phase);
		switch (kind) {
			case 1: return 2.0 / Math.PI * Math.Asin(s);
			case 2: return Math.Tanh(s * 3.0) * 0.8;
			case 3: { double t = (phase / (2 * Math.PI)) % 1.0; return (2 * t - 1) * 0.6; }
			case 4: return s * 0.7 + Math.Sin(phase * 2.76) * 0.2 + Math.Sin(phase * 5.4) * 0.1;
			default: return s;
		}
	}

	// Tone with attack and exponential decay (decay = seconds to fall to ~1/e)
	public static void Tone(float[] b, double start, double dur, double f0, double f1, int kind, double vol, double attack, double decay, double vibrato) {
		int s0 = (int)(start * Rate), n = (int)(dur * Rate);
		double phase = 0;
		for (int i = 0; i < n; i++) {
			int idx = s0 + i; if (idx < 0) continue;
			idx %= b.Length; // wrap: lets loops end seamlessly
			double t = (double)i / Rate, k = (double)i / n;
			double f = f0 + (f1 - f0) * k;
			if (vibrato > 0) f *= 1.0 + 0.012 * Math.Sin(2 * Math.PI * 5.5 * t) * vibrato;
			phase += 2 * Math.PI * f / Rate;
			double env = (t < attack ? t / attack : Math.Exp(-(t - attack) / decay));
			double release = Math.Min(1.0, (dur - t) / 0.02); // avoid clicks
			b[idx] += (float)(Wave(kind, phase) * env * release * vol);
		}
	}

	// Filtered noise with a moving low-pass cutoff (swooshes, cracks, snares, crickets)
	public static void Noise(float[] b, double start, double dur, double cut0, double cut1, double vol, double attack, double decay) {
		int s0 = (int)(start * Rate), n = (int)(dur * Rate);
		double lp = 0, lp2 = 0;
		for (int i = 0; i < n; i++) {
			int idx = (s0 + i) % b.Length;
			double t = (double)i / Rate, k = (double)i / n;
			double cut = cut0 + (cut1 - cut0) * Math.Sin(Math.PI * Math.Min(1, k));
			double a = 1 - Math.Exp(-2 * Math.PI * cut / Rate);
			double white = rng.NextDouble() * 2 - 1;
			lp += a * (white - lp); lp2 += a * (lp - lp2);
			double env = (t < attack ? t / attack : Math.Exp(-(t - attack) / decay));
			double release = Math.Min(1.0, (dur - t) / 0.01);
			b[idx] += (float)(lp2 * env * release * vol * 2.5);
		}
	}

	public static void Kick(float[] b, double start, double vol) { Tone(b, start, 0.35, 150, 45, 0, vol, 0.002, 0.12, 0); }
	public static void Snare(float[] b, double start, double vol) { Noise(b, start, 0.22, 5000, 3000, vol, 0.002, 0.06); Tone(b, start, 0.1, 220, 180, 1, vol * 0.4, 0.002, 0.05, 0); }
	public static void Hat(float[] b, double start, double vol) { Noise(b, start, 0.06, 9000, 9000, vol * 0.5, 0.001, 0.015); }

	// Simple echo (wraps for loops when wrap = true)
	public static void Echo(float[] b, double delay, double feedback, int repeats, bool wrap) {
		int d = (int)(delay * Rate);
		float[] src = (float[])b.Clone();
		double g = feedback;
		for (int r = 1; r <= repeats; r++, g *= feedback) {
			for (int i = 0; i < src.Length; i++) {
				int j = i + d * r;
				if (j >= b.Length) { if (!wrap) break; j %= b.Length; }
				b[j] += (float)(src[i] * g);
			}
		}
	}

	public static void Save(float[] b, string path, double peak) {
		double max = 1e-9;
		foreach (float v in b) max = Math.Max(max, Math.Abs(v));
		double gain = peak / max;
		using (var w = new BinaryWriter(File.Create(path))) {
			int bytes = b.Length * 2;
			w.Write(new char[] { 'R', 'I', 'F', 'F' }); w.Write(36 + bytes);
			w.Write(new char[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' }); w.Write(16);
			w.Write((short)1); w.Write((short)1); w.Write(Rate); w.Write(Rate * 2); w.Write((short)2); w.Write((short)16);
			w.Write(new char[] { 'd', 'a', 't', 'a' }); w.Write(bytes);
			foreach (float v in b) w.Write((short)Math.Max(-32767, Math.Min(32767, v * gain * 32767)));
		}
	}

	// ---- Sound effects ----

	public static void Banner(string p) { // bright three-note chime
		var b = Buf(1.4);
		int[] n = { 84, 88, 91, 96 };
		for (int i = 0; i < n.Length; i++) Tone(b, i * 0.07, 1.2 - i * 0.07, Note(n[i]), Note(n[i]), 4, 0.5, 0.004, 0.35, 0);
		Echo(b, 0.12, 0.25, 3, false); Save(b, p, 0.8);
	}

	public static void Harvest(string p) { // bubbly pop
		var b = Buf(0.25);
		Tone(b, 0, 0.18, 380, 980, 0, 0.9, 0.002, 0.045, 0);
		Noise(b, 0, 0.03, 4000, 4000, 0.25, 0.001, 0.008);
		Save(b, p, 0.85);
	}

	public static void Sell(string p) { // coin jingle
		var b = Buf(0.9);
		Tone(b, 0, 0.5, Note(83), Note(83), 4, 0.6, 0.002, 0.12, 0);
		Tone(b, 0.09, 0.8, Note(88), Note(88), 4, 0.7, 0.002, 0.22, 0);
		Tone(b, 0.09, 0.8, Note(95), Note(95), 0, 0.2, 0.002, 0.18, 0);
		Save(b, p, 0.8);
	}

	public static void Attack(string p) { // swoosh + soft thump
		var b = Buf(0.35);
		Noise(b, 0, 0.28, 400, 3500, 0.9, 0.04, 0.12);
		Tone(b, 0.08, 0.12, 160, 70, 0, 0.6, 0.002, 0.04, 0);
		Save(b, p, 0.8);
	}

	public static void LevelUp(string p) { // rising arpeggio fanfare
		var b = Buf(1.8);
		int[] n = { 72, 76, 79, 84 };
		for (int i = 0; i < 4; i++) Tone(b, i * 0.09, 0.4, Note(n[i]), Note(n[i]), 1, 0.55, 0.005, 0.15, 0);
		foreach (int m in new int[] { 72, 76, 79, 84, 88 }) Tone(b, 0.38, 1.3, Note(m), Note(m), 2, 0.22, 0.01, 0.5, 0.6);
		Tone(b, 0.38, 1.3, Note(96), Note(96), 4, 0.25, 0.005, 0.4, 0);
		Echo(b, 0.11, 0.2, 2, false); Save(b, p, 0.8);
	}

	public static void NightWarning(string p) { // low horn, rising slightly
		var b = Buf(2.4);
		foreach (double mult in new double[] { 1.0, 1.5, 2.0 })
			Tone(b, 0, 2.2, 98 * mult, 104 * mult, 3, 0.4 / mult, 0.25, 1.6, 1.0);
		Tone(b, 0, 2.2, 49, 52, 0, 0.35, 0.3, 1.6, 0);
		Save(b, p, 0.8);
	}

	public static void Mutation(string p) { // magic sparkle glissando
		var b = Buf(1.5);
		int[] scale = { 0, 2, 4, 7, 9 };
		for (int i = 0; i < 14; i++) {
			int m = 79 + scale[i % 5] + 12 * (i / 5);
			Tone(b, i * 0.045, 0.5, Note(m), Note(m), 4, 0.35, 0.002, 0.12, 0);
		}
		Tone(b, 0, 1.2, Note(67), Note(79), 0, 0.15, 0.3, 0.5, 0);
		Echo(b, 0.09, 0.35, 4, false); Save(b, p, 0.75);
	}

	// ---- Music loops (tails wrap around, so they loop seamlessly) ----

	public static void Day(string p) { // gentle music box over soft chords, C major, 96 bpm
		double beat = 60.0 / 96; int bars = 8;
		var b = Buf(bars * 4 * beat);
		int[][] chords = { new[] { 48, 55, 64 }, new[] { 45, 52, 60 }, new[] { 41, 48, 57 }, new[] { 43, 50, 59 } };
		int[] melody = { 76, 79, 81, 79, 76, 74, 72, 74,  76, 74, 72, 69, 67, 69, 72, 74,
		                 72, 74, 76, 79, 81, 79, 76, 74,  74, 72, 71, 72, 74, 76, 74, 72 };
		for (int bar = 0; bar < bars; bar++) {
			var c = chords[bar % 4];
			foreach (int m in c) Tone(b, bar * 4 * beat, 4 * beat, Note(m), Note(m), 1, 0.12, 0.3, 2.5, 0);
			Tone(b, bar * 4 * beat, 2 * beat, Note(c[0] - 12), Note(c[0] - 12), 0, 0.22, 0.02, 0.8, 0);
			Tone(b, (bar * 4 + 2) * beat, 2 * beat, Note(c[1] - 12), Note(c[1] - 12), 0, 0.18, 0.02, 0.8, 0);
			for (int i = 0; i < 4; i++) {
				int m = melody[(bar * 4 + i) % melody.Length];
				Tone(b, (bar * 4 + i) * beat, 1.2, Note(m), Note(m), 4, 0.3, 0.003, 0.45, 0);
				if (i % 2 == 1) Tone(b, (bar * 4 + i + 0.5) * beat, 0.6, Note(m + 12), Note(m + 12), 4, 0.1, 0.003, 0.2, 0);
			}
		}
		Echo(b, beat * 0.75, 0.25, 3, true); Save(b, p, 0.55);
	}

	public static void Night(string p) { // calm mysterious pad + crickets + distant bells, A minor
		double dur = 24; var b = Buf(dur);
		int[][] pads = { new[] { 57, 60, 64 }, new[] { 53, 57, 60 }, new[] { 55, 59, 62 }, new[] { 52, 56, 59 } };
		for (int i = 0; i < 4; i++)
			foreach (int m in pads[i]) Tone(b, i * 6, 7.5, Note(m - 12), Note(m - 12), 0, 0.12, 2.0, 4.0, 0.3);
		for (double t = 0.3; t < dur; t += 0.9 + (t * 7 % 1.0) * 0.8) // crickets: short high chirp bursts
			for (int k = 0; k < 3; k++) Tone(b, t + k * 0.05, 0.035, 4600, 4700, 0, 0.05, 0.004, 0.01, 0);
		int[] bells = { 81, 76, 79, 72, 76, 74 };
		for (int i = 0; i < bells.Length; i++) Tone(b, 1.5 + i * 3.9, 3.5, Note(bells[i]), Note(bells[i]), 4, 0.12, 0.005, 1.0, 0);
		Echo(b, 0.42, 0.35, 4, true); Save(b, p, 0.5);
	}

	public static void Feast(string p) { // driving boss music, D minor, 132 bpm
		double beat = 60.0 / 132; int bars = 8;
		var b = Buf(bars * 4 * beat);
		int[] roots = { 38, 38, 34, 36, 38, 38, 41, 40 };
		for (int bar = 0; bar < bars; bar++) {
			double t0 = bar * 4 * beat;
			for (int i = 0; i < 4; i++) {
				Kick(b, t0 + i * beat, 0.9);
				if (i % 2 == 1) Snare(b, t0 + i * beat, 0.5);
				Hat(b, t0 + (i + 0.5) * beat, 0.4);
			}
			int r = roots[bar];
			for (int e = 0; e < 8; e++) // galloping bass
				Tone(b, t0 + e * beat * 0.5, beat * 0.45, Note(r + (e % 4 == 3 ? 7 : 0)), Note(r + (e % 4 == 3 ? 7 : 0)), 2, 0.35, 0.005, 0.15, 0);
			foreach (int m in new[] { r + 24, r + 27, r + 31 }) // brass-like stab
				Tone(b, t0, beat * 1.5, Note(m), Note(m), 3, 0.18, 0.02, 0.4, 0.5);
		}
		Save(b, p, 0.7);
	}
}
"@

$items = [ordered]@{
	"Banner" = { param($p) [Synth]::Banner($p) }
	"Harvest" = { param($p) [Synth]::Harvest($p) }
	"Sell" = { param($p) [Synth]::Sell($p) }
	"Attack" = { param($p) [Synth]::Attack($p) }
	"LevelUp" = { param($p) [Synth]::LevelUp($p) }
	"NightWarning" = { param($p) [Synth]::NightWarning($p) }
	"Mutation" = { param($p) [Synth]::Mutation($p) }
	"MusicDay" = { param($p) [Synth]::Day($p) }
	"MusicNight" = { param($p) [Synth]::Night($p) }
	"MusicFeast" = { param($p) [Synth]::Feast($p) }
}
foreach ($name in $items.Keys) {
	$path = Join-Path $out "MoonlitGrove_$name.wav"
	& $items[$name] $path
	"{0,-30} {1,8:N0} KB" -f (Split-Path $path -Leaf), ((Get-Item $path).Length / 1KB)
}
