package CASolver

import (
	"strconv"

	minhashlsh "github.com/ekzhu/minhash-lsh"
)

var (
	char_ngram = 5
)

func splitShingles(line string) (shingles []string) {

	// Pad to ensure we get at least one shingle for short strings.
	var i int
	if len(line) < char_ngram {
		for i = len(line); i < char_ngram; i++ {
			line += " "
		}
	}
	for i := 0; i < len(line)-char_ngram+1; i++ {
		shingles = append(shingles, line[i:i+char_ngram])
	}
	return
}

func removeDups(slice []uint64) []uint64 {
	keys := make(map[uint64]bool)
	list := []uint64{}
	for _, entry := range slice {
		if _, value := keys[entry]; !value {
			keys[entry] = true
			list = append(list, entry)
		}
	}
	return list
}
func intersection(s1, s2 []uint64) (s_intersection []uint64) {
	hash := make(map[uint64]bool)
	for _, item := range s1 {
		hash[item] = true
	}
	for _, item := range s2 {
		// If elements present in the hashmap then append intersection list.
		if hash[item] {
			s_intersection = append(s_intersection, item)
		}
	}
	//Remove dups from slice.
	s_intersection = removeDups(s_intersection)
	return
}

func union(s1, s2 []uint64) (s_union []uint64) {
	hash := make(map[uint64]bool)
	s_union = s1

	for _, item := range s1 {
		hash[item] = true
	}
	for _, item := range s2 {
		if _, ok := hash[item]; !ok {
			s_union = append(s_union, item)
		}
	}
	return s_union
}

func computeSorensenDiceSimilariy(s1, s2 []uint64) float64 {
	s_intersection := intersection(removeDups(s1), removeDups(s2))
	numerator := 2 * len(s_intersection)
	denominator := len(removeDups(s1)) + len(removeDups(s2))
	DSC_similarity := float64(numerator) / float64(denominator)
	return DSC_similarity
}

func addMinhashToLsh(minhashLsh *minhashlsh.MinhashLSH, event *Event) error {

	seed := int64(1)
	numHash := 10
	mh := minhashlsh.NewMinhash(seed, numHash)
	var sig []uint64

	if event.Signature == nil && event.MsgLen > 0 {
		shingles := splitShingles(event.Msg)
		for _, shingle := range shingles {
			mh.Push([]byte(shingle))
		}
		sig = mh.Signature()
	} else {
		sig = event.Signature
	}

	minhashLsh.Add(event.Id, sig)
	(*event).Signature = sig

	return nil
}

func FindDataDependencies_All_Events(allEvents map[int]*Event, dataList []*Event) {

	minhashLsh := minhashlsh.NewMinhashLSH16(10, 0.5, 1)

	for _, event := range dataList {
		addMinhashToLsh(minhashLsh, event)
	}

	minhashLsh.Index()

	for _, event := range dataList {
		event.DataSimilarities = make(map[string]float64)

		event_dup := minhashLsh.Query(event.Signature)
		for _, e := range event_dup {
			if e.(int) == event.Id {
				continue
			}
			dup_sig := allEvents[e.(int)].Signature
			similarity := computeSorensenDiceSimilariy(event.Signature, dup_sig)
			event.DataSimilarities[strconv.Itoa(e.(int))] = similarity
		}
	}
}
