"""Imports sounds from licensed third-party packs into assets/audio/licensed/.

That folder is gitignored: the packs may be used in the game but not
redistributed, and this repository is public. A fresh clone simply plays the
generated sounds; run this once with your own copy of the pack to add them.

    python tools/audio/import_licensed.py <path to Minifantasy_Creatures_SFX_v3.0.zip or folder>

Each file is converted to 16-bit mono 44.1 kHz, its leading silence trimmed,
its tail cut where it falls below -46 dB (with a short fade) and its peak
normalised, so it sits at the same level as the generated effects. Names that
also exist in assets/audio/sfx override those; "<name>_2", "<name>_3"... are
variants the game picks between at random.
"""
import io
import math
import os
import struct
import sys
import wave
import zipfile

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "licensed")
PACK = "Minifantasy_Creatures_SFX_v3.0/"

# game name -> (file in the pack, peak)
MAP = {
    # --- the Kindled ---
    "step_stone_0": ("Humanoids/Human/20_human_walk_stone_1.wav", 0.8),
    "step_stone_1": ("Humanoids/Human/21_human_walk_stone_2.wav", 0.8),
    "step_stone_2": ("Humanoids/Human/22_human_walk_stone_3.wav", 0.8),
    "step_stone_3": ("Humanoids/Orc/15_orc_walk_stone_2.wav", 0.8),
    "dodge": ("Humanoids/Human/18_human_dash_1.wav", 0.85),
    "dodge_2": ("Humanoids/Human/19_human_dash_2.wav", 0.85),
    "hurt": ("Humanoids/Human/10_human_damage_1.wav", 0.85),
    "hurt_2": ("Humanoids/Human/11_human_damage_2.wav", 0.85),
    "hurt_3": ("Humanoids/Human/12_human_damage_3.wav", 0.85),
    "player_death": ("Humanoids/Human/23_human_death_spin.wav", 0.85),
    # --- voices: v_<kind>_<event> ---
    "v_zombie_attack": ("Monsters/Zombie/01_Zombie_attack_1.wav", 0.85),
    "v_zombie_attack_2": ("Monsters/Zombie/02_Zombie_attack_2.wav", 0.85),
    "v_zombie_hurt": ("Monsters/Zombie/03_Zombie_damage_1.wav", 0.85),
    "v_zombie_hurt_2": ("Monsters/Zombie/04_Zombie_damage_2.wav", 0.85),
    "v_zombie_die": ("Monsters/Zombie/05_Zombie_death.wav", 0.85),
    "v_zombie_idle": ("Monsters/Zombie/07_Zombie_idle_2.wav", 0.7),
    "v_skeleton_attack": ("Monsters/Skeleton/01_Skeleton_attack.wav", 0.85),
    "v_skeleton_hurt": ("Monsters/Skeleton/02_Skeleton_damage.wav", 0.85),
    "v_skeleton_die": ("Monsters/Skeleton/03_Skeleton_death.wav", 0.85),
    "v_skeleton_idle": ("Monsters/Skeleton/04_Skeleton_idle_1.wav", 0.7),
    "v_skeleton_idle_2": ("Monsters/Skeleton/05_Skeleton_idle_2.wav", 0.7),
    "v_skeleton_idle_3": ("Monsters/Skeleton/06_Skeleton_idle_3.wav", 0.7),
    "v_slime_hurt": ("Monsters/Slime/01_Slime_damage.wav", 0.85),
    "v_slime_die": ("Monsters/Slime/02_Slime_death.wav", 0.85),
    "v_slime_jump": ("Monsters/Slime/04_Slime_jump.wav", 0.8),
    "v_bigslime_hurt": ("Big_Guys/Mother_Slime/01_Mother_Slime_damage.wav", 0.85),
    "v_bigslime_die": ("Big_Guys/Mother_Slime/04_Mother_Slime_death.wav", 0.85),
    "v_bigslime_jump": ("Big_Guys/Mother_Slime/02_Mother_Slime_jump.wav", 0.8),
    "v_bigslime_land": ("Big_Guys/Mother_Slime/03_Mother_Slime_land.wav", 0.85),
    "v_wolf_attack": ("Beasts/Wolf/01_Wolf_attack_1a.wav", 0.85),
    "v_wolf_attack_2": ("Beasts/Wolf/03_Wolf_attack_2a.wav", 0.85),
    "v_wolf_hurt": ("Beasts/Wolf/08_Wolf_damage_1.wav", 0.85),
    "v_wolf_hurt_2": ("Beasts/Wolf/09_Wolf_damage_2.wav", 0.85),
    "v_wolf_die": ("Beasts/Wolf/07_Wolf_death.wav", 0.85),
    "v_wolf_idle": ("Beasts/Wolf/05_Wolf_growl_1.wav", 0.7),
    "v_wolf_idle_2": ("Beasts/Wolf/06_Wolf_growl_2.wav", 0.7),
    "v_bat_attack": ("Beasts/Bat/04_Bat_attack_1.wav", 0.85),
    "v_bat_hurt": ("Beasts/Bat/01_Bat_cry_short_a.wav", 0.8),
    "v_bat_hurt_2": ("Beasts/Bat/02_Bat_cry_short_b.wav", 0.8),
    "v_bat_die": ("Beasts/Bat/10_Bat_death.wav", 0.85),
    "v_bat_idle": ("Beasts/Bat/06_Bat_wing_flap_single_1.wav", 0.6),
    "v_bat_idle_2": ("Beasts/Bat/07_Bat_wing_flap_single_2.wav", 0.6),
    "v_brute_attack": ("Big_Guys/Large_Humanoid/01_Large_Humanoid_Attack_1.wav", 0.9),
    "v_brute_attack_2": ("Big_Guys/Large_Humanoid/02_Large_Humanoid_Attack_2.wav", 0.9),
    "v_brute_hurt": ("Big_Guys/Large_Humanoid/03_Large_Humanoid_Damage_1.wav", 0.85),
    "v_brute_hurt_2": ("Big_Guys/Large_Humanoid/04_Large_Humanoid_Damage_2.wav", 0.85),
    "v_brute_die": ("Big_Guys/Large_Humanoid/05_Large_Humanoid_Death.wav", 0.9),
    "v_brute_idle": ("Big_Guys/Large_Humanoid/06_Large_Humanoid_Idle_1.wav", 0.7),
    "v_brute_jump": ("Big_Guys/Large_Humanoid/08_Large_Humanoid_Jump.wav", 0.85),
    "v_brute_land": ("Big_Guys/Large_Humanoid/09_Large_Humanoid_Land.wav", 0.9),
    "v_brute_step": ("Big_Guys/Large_Humanoid/10_Large_Humanoid_Step_1.wav", 0.85),
    "v_brute_step_2": ("Big_Guys/Large_Humanoid/11_Large_Humanoid_Step_2.wav", 0.85),
    "v_minotaur_step": ("Big_Guys/Large_Humanoid/10_Large_Humanoid_Step_1.wav", 0.85),
    "v_minotaur_step_2": ("Big_Guys/Large_Humanoid/11_Large_Humanoid_Step_2.wav", 0.85),
    "v_minotaur_jump": ("Big_Guys/Large_Humanoid/08_Large_Humanoid_Jump.wav", 0.85),
    "v_minotaur_land": ("Big_Guys/Large_Humanoid/09_Large_Humanoid_Land.wav", 0.9),
    "v_minotaur_attack": ("Big_Guys/Minotaur/01_Minotaur_Attack.wav", 0.9),
    "v_minotaur_hurt": ("Big_Guys/Minotaur/02_Minotaur_Damage_1.wav", 0.85),
    "v_minotaur_hurt_2": ("Big_Guys/Minotaur/03_Minotaur_Damage_2.wav", 0.85),
    "v_minotaur_die": ("Big_Guys/Minotaur/04_Minotaur_Death.wav", 0.9),
    "v_minotaur_idle": ("Big_Guys/Minotaur/06_Minotaur_Idle_2.wav", 0.7),
    "v_beast_attack": ("Big_Guys/Wargo/01_Wargo_Attack_01.wav", 0.85),
    "v_beast_attack_2": ("Big_Guys/Wargo/02_Wargo_Attack_02.wav", 0.85),
    "v_beast_hurt": ("Big_Guys/Wargo/03_Wargo_Damage_01.wav", 0.85),
    "v_beast_hurt_2": ("Big_Guys/Wargo/04_Wargo_Damage_02.wav", 0.85),
    "v_beast_die": ("Big_Guys/Wargo/05_Wargo_Death.wav", 0.85),
    "v_pumpkin_attack": ("Monsters/Pumpkin_Horror/01_Pumpkin_attack.wav", 0.85),
    "v_pumpkin_hurt": ("Monsters/Pumpkin_Horror/03_Pumpkin_damage_2.wav", 0.85),
    "v_pumpkin_die": ("Monsters/Pumpkin_Horror/04_Pumpkin_death.wav", 0.85),
    "v_pumpkin_idle": ("Monsters/Pumpkin_Horror/05_Pumpkin_idle_1.wav", 0.7),
    "v_wildfire_hurt": ("Monsters/Wildfire/01_Wildfire_Damage.wav", 0.8),
    "v_wildfire_die": ("Monsters/Wildfire/02_Wildfire_Death.wav", 0.85),
    "v_orc_hurt": ("Humanoids/Orc/07_orc_damage_1.wav", 0.85),
    "v_orc_hurt_2": ("Humanoids/Orc/08_orc_damage_2.wav", 0.85),
    "v_orc_die": ("Humanoids/Orc/13_orc_death_spin.wav", 0.85),
}


def read_wav(data: bytes):
    w = wave.open(io.BytesIO(data), "rb")
    ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
    raw = w.readframes(n)
    w.close()
    if sw == 3:
        vals = [int.from_bytes(raw[i:i + 3], "little", signed=True) / 8388608.0 for i in range(0, len(raw), 3)]
    elif sw == 2:
        vals = [v / 32768.0 for v in struct.unpack("<%dh" % (len(raw) // 2), raw)]
    else:
        raise ValueError("unsupported sample width %d" % sw)
    mono = [sum(vals[i:i + ch]) / ch for i in range(0, len(vals), ch)]
    return mono, sr


def process(mono, sr, peak):
    lead_thr = 0.01
    start = next((i for i, v in enumerate(mono) if abs(v) > lead_thr), 0)
    start = max(0, start - int(0.004 * sr))
    tail_thr = 0.005  # about -46 dB
    end = max((i for i, v in enumerate(mono) if abs(v) > tail_thr), default=len(mono) - 1)
    end = min(len(mono), end + int(0.04 * sr))
    out = mono[start:end]
    fade = min(len(out), int(0.03 * sr))
    for k in range(fade):
        out[len(out) - fade + k] *= 1.0 - (k + 1) / fade
    p = max((abs(v) for v in out), default=0.0)
    g = peak / p if p > 0.0 else 1.0
    return [max(-1.0, min(1.0, v * g)) for v in out]


def write_wav(path, samples, sr):
    w = wave.open(path, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(sr)
    w.writeframes(struct.pack("<%dh" % len(samples), *[int(round(v * 32767)) for v in samples]))
    w.close()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    src = sys.argv[1]
    if os.path.isdir(src):
        base = src if os.path.basename(src.rstrip("/\\")) + "/" == PACK else os.path.join(src, PACK)
        get = lambda rel: open(os.path.join(base, rel), "rb").read()
    else:
        z = zipfile.ZipFile(src)
        get = lambda rel: z.read(PACK + rel)
    os.makedirs(OUT, exist_ok=True)
    for name, (rel, peak) in MAP.items():
        mono, sr = read_wav(get(rel))
        out = process(mono, sr, peak)
        write_wav(os.path.join(OUT, name + ".wav"), out, sr)
        print("%-22s <- %s (%.2fs)" % (name, rel, len(out) / sr))
    print("%d sounds written to %s" % (len(MAP), os.path.normpath(OUT)))


if __name__ == "__main__":
    main()
