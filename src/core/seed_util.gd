class_name SeedUtil
## Derivación determinista de seeds por fase (ver docs/adr/0001-deterministic-seed-derivation.md).
##
## Nunca uses randf()/randi()/randomize() globales en la generación: pide un RNG con make_rng().

const _FNV_OFFSET_HI: int = 0xcbf29ce4
const _FNV_OFFSET_LO: int = 0x84222325
# prime = 0x100000001b3 = 2^40 + 0x1b3 -> partes de 32 bits: hi = 0x100, lo = 0x1b3
const _FNV_PRIME_HI: int = 0x100
const _FNV_PRIME_LO: int = 0x1b3
const _MASK_32: int = 0xFFFFFFFF
const _TWO_POW_31: int = 0x80000000
const _TWO_POW_32: int = 0x100000000


## Seed de la fase `phase_name` para el mundo `world_seed`.
static func derive(world_seed: int, phase_name: StringName) -> int:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, world_seed)
	bytes.append(0)
	bytes.append_array(String(phase_name).to_utf8_buffer())
	return fnv1a_64(bytes)


## RNG propio de una fase, ya sembrado.
static func make_rng(world_seed: int, phase_name: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = derive(world_seed, phase_name)
	return rng


## FNV-1a de 64 bits. Se calcula con dos mitades de 32 bits para no depender
## del desbordamiento de enteros con signo. Devuelve el resultado como int64 con signo.
static func fnv1a_64(bytes: PackedByteArray) -> int:
	var hi: int = _FNV_OFFSET_HI
	var lo: int = _FNV_OFFSET_LO
	for b: int in bytes:
		lo = lo ^ b
		# (hi, lo) * (PRIME_HI, PRIME_LO) mod 2^64. hi * PRIME_HI queda por encima de 2^64 y se descarta.
		var lo_product: int = lo * _FNV_PRIME_LO
		var carry: int = lo_product >> 32
		var new_hi: int = hi * _FNV_PRIME_LO + lo * _FNV_PRIME_HI + carry
		hi = new_hi & _MASK_32
		lo = lo_product & _MASK_32
	return _join_signed(hi, lo)


# Combina dos mitades de 32 bits sin signo en un int64 con signo, sin desbordamiento.
static func _join_signed(hi: int, lo: int) -> int:
	if hi >= _TWO_POW_31:
		return (hi - _TWO_POW_32) * _TWO_POW_32 + lo
	return hi * _TWO_POW_32 + lo
