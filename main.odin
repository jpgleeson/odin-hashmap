package main

import "core:fmt"
import "core:hash"
import "core:time"

keyvalpair :: struct {
	key: string,
	val: string
}

Hashmap :: struct {
	buckets: [][dynamic]keyvalpair,
	count: u32
}

N :: 1000000

bench :: proc() {
	keys := make([]string, N)
	for i in 0..<N {
		keys[i] = fmt.aprintf("key%d", i)
	}

	m: Hashmap
	defer destroy(&m)

	start := time.tick_now()
	for k in keys {
		set(&m, k, k)
	}
	insert := time.tick_since(start)
	found := 0
	start = time.tick_now()
	for k in keys {
		if _, ok := get(&m, k); ok {
			found += 1
		}
	}
	lookup := time.tick_since(start)
	fmt.printfln("mine:     insert %.1fms  lookup %.1fms  found %d",
		time.duration_milliseconds(insert), time.duration_milliseconds(lookup), found)

	n: map[string]string
	defer delete(n)

	start = time.tick_now()
	for k in keys do n[k] = k
	ninsert := time.tick_since(start)
	start = time.tick_now()
	nfound := 0
	for k in keys {
		if _, ok := n[k]; ok do nfound += 1
	}
	nlookup := time.tick_since(start)
	fmt.printfln("built-in: insert %.1fms  lookup %.1fms  found %d",
			time.duration_milliseconds(ninsert), time.duration_milliseconds(nlookup), nfound)
}

main :: proc() {
	fmt.println("Yes")

	hMap := Hashmap{}
	defer destroy(&hMap)
	set(&hMap, "test", "val")

	stored, _ := get(&hMap, "test")

	for jk := 0; jk < 1000; jk += 1 {
		set(&hMap, fmt.tprintf("key%d", jk), fmt.tprintf("val%d", jk))
	}

	set(&hMap, "test", "valset")
	stored, _ = get(&hMap, "test")

	unset(&hMap, "test")
	stored, _ = get(&hMap, "test")

	fmt.println("=========")


	bench()
}

set :: proc (hMap: ^Hashmap, k: string, v: string) {
	if len(hMap.buckets) == 0 {
			hMap.buckets = make([][dynamic]keyvalpair, 8)
	}

	h := hash.fnv32a(transmute([]byte)k)
	bucket := &hMap.buckets[h & u32(len(hMap.buckets) - 1)] // bitwise here as a bit faster as long as we keep to power of 2 buckets
	for &kv in bucket {
		if kv.key == k {
			kv.val = v
			return
		}
	}
	append(bucket, keyvalpair{key = k, val = v})
	hMap.count += 1

	if hMap.count * 5 > u32(len(hMap.buckets) * 4) {
		grow(hMap)
	}
}

get :: proc (hMap: ^Hashmap, k: string) -> (string, bool) {
	if len(hMap.buckets) == 0 {
		return "", false
	}
	h := hash.fnv32a(transmute([]byte)k)
	bucket := &hMap.buckets[h & u32(len(hMap.buckets) - 1)]

	for kv in bucket {
		if kv.key == k {
			return kv.val, true
		}
	}

	return "", false
}

unset :: proc (hMap: ^Hashmap, k: string) -> (string, bool) {
	if len(hMap.buckets) == 0 {
		return "", false
	}

	h := hash.fnv32a(transmute([]byte)k)
	bucket := &hMap.buckets[h & u32(len(hMap.buckets) - 1)]

	for kv, i in bucket {
		if kv.key == k {
			unordered_remove(bucket, i)
			hMap.count -= 1
			return kv.val, true
		}
	}

	return "", false
}

grow :: proc (hmap: ^Hashmap) {
	old := &hmap.buckets
	new_buckets := make([][dynamic]keyvalpair, len(old) * 2)
	for ob in old {
		for kv in ob {
			h := hash.fnv32a(transmute([]byte)kv.key)
			bucket := &new_buckets[h & u32(len(new_buckets) - 1)]

			append(bucket, keyvalpair{key = kv.key, val = kv.val})
		}
	}

	free_buckets(hmap)
	hmap.buckets = new_buckets
}

destroy :: proc (hmap: ^Hashmap) {
	free_buckets(hmap)
	hmap^ = {}
}

free_buckets :: proc(hmap: ^Hashmap) {
	for &bucket in hmap.buckets {
		delete(bucket)
	}
	delete(hmap.buckets)
}
