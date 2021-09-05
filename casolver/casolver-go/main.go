package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"io/ioutil"
	"log"
	"os"

	casolver "casolver-go/CASolver"
)

func parseInputFile(event_filename string) (map[int]*casolver.Event, []*casolver.Event, []*casolver.Event, error) {

	allEvents := make(map[int]*casolver.Event)
	var orderedEvents []*casolver.Event
	var dataList []*casolver.Event

	log.Printf("Loading events from: %s\n", event_filename)

	// Open our jsonFile
	jsonFile, err := os.Open(event_filename)
	// if we os.Open returns an error then handle it
	if err != nil {
		log.Fatalf("Error opening input file: %v\n", err)
	}
	// defer the closing of our jsonFile so that we can parse it later on
	defer jsonFile.Close()

	received_JSON, err := ioutil.ReadAll(jsonFile) //This reads raw request body
	if err != nil {
		panic(err)
	}

	var val []map[string]interface{} // <---- This must be an array to match input
	if err := json.Unmarshal(received_JSON, &val); err != nil {
		panic(err)
	}

	for _, v := range val {

		var e = &casolver.Event{}
		e.Etype = v["type"].(string)
		e.Timestamp = v["timestamp"].(string)
		e.Id = int(v["id"].(float64))
		e.Thread = v["thread"].(string)
		e.Pid = uint32(v["pid"].(float64))
		e.Loc = v["loc"].(string)
		e.Order = int(v["order"].(float64))
		dependency := v["dependency"]
		if dependency != nil {
			dep_str := dependency.(string)
			e.Dependency = &dep_str
		}
		dependencies := v["dependencies"]
		if dependencies != nil {
			e.Dependencies = make([]string, 0, len(dependencies.([]interface{})))
			for _, dep := range dependencies.([]interface{}) {
				e.Dependencies = append(e.Dependencies, dep.(string))
			}
		} else {
			e.Dependencies = make([]string, 0)
		}

		if e.Etype == "CONNECT" || e.Etype == "ACCEPT" || e.Etype == "SND" || e.Etype == "RCV" {
			e.Socket = v["socket"].(string)
			e.Socket_type = v["socket_type"].(string)
			e.Src = v["src"].(string)
			e.Src_port = int(v["src_port"].(float64))
			e.Dst = v["dst"].(string)
			e.Dst_port = int(v["dst_port"].(float64))
		}

		if e.Etype == "OPEN" || e.Etype == "RD" || e.Etype == "WR" {
			filename := v["filename"]
			if filename != nil {
				e.Filename = filename.(string)
			}
			fd := v["fd"]
			if fd != nil {
				hfd := int(fd.(float64))
				e.Fd = &hfd
			}
			offset := v["offset"]
			if offset != nil {
				hoff := int64(offset.(float64))
				e.Offset = &hoff
			}
		}

		size := v["size"]
		if size != nil {
			hsize := int64(size.(float64))
			e.Size = &hsize
		}
		returned_value := v["returned_value"]
		if returned_value != nil {
			hreturned_value := int64(returned_value.(float64))
			e.Returned_value = &hreturned_value
		}

		message := v["message"]
		if message != nil {
			e.Message = message.(string)
		}

		d := v["data"]
		if d != nil {
			data := &casolver.Data{}
			dv := d.(map[string]interface{})

			comm := dv["comm"]
			if comm != nil {
				data.Comm = comm.(string)
			}
			host := dv["host"]
			if host != nil {
				data.Host = host.(string)
			}
			msg := dv["msg"]
			if msg != nil {
				data.Msg = msg.(string)
			}
			msg_len := dv["msg_len"]
			if msg_len != nil {
				data.MsgLen = int64(msg_len.(float64))
			} else {
				data.MsgLen = -1
			}
			signature := dv["signature"]
			if signature != nil {
				for _, fp := range signature.([]interface{}) {
					data.Signature = append(data.Signature, uint64(fp.(float64)))
				}
			}
			e.Data = *data
		}

		allEvents[e.Id] = e
		orderedEvents = append(orderedEvents, e)
		if e.Etype == "SND" || e.Etype == "RCV" || e.Etype == "RD" || e.Etype == "WR" {
			if e.Returned_value != nil && *e.Returned_value > 0 {
				if e.Signature != nil || e.MsgLen > 0 {
					dataList = append(dataList, e)
				}
			}
		}
	}

	return allEvents, orderedEvents, dataList, nil
}

func ArrayToJson(events []*casolver.Event) ([]byte, error) {
	buffer := &bytes.Buffer{}
	encoder := json.NewEncoder(buffer)
	encoder.SetEscapeHTML(false)
	err := encoder.Encode(events)
	return buffer.Bytes(), err
}

func outputResult(output_file string, orderedEvents []*casolver.Event) {
	out_file, err := os.Create(output_file)
	if err != nil {
		log.Fatalf("Error opening output file: %v\n", err)
	}
	m, err := ArrayToJson(orderedEvents)
	if err != nil {
		log.Fatalf("Error enconding the event: %v\n", err)
	}
	if len(m) > 0 {
		_, err := out_file.Write(m)
		if err != nil {
			log.Fatalf("Error saving event: %v\n", err)
		}
	}
}

func main() {
	events_file := flag.String("event_file", "", "input file (falcon-solver output)")
	output_file := flag.String("output_file", "casolver_trace.json", "output file")
	flag.Parse()

	if *events_file == "" {
		log.Fatalf("Missing events_file!")
	}

	allEvents, orderedEvents, dataList, err := parseInputFile(*events_file)
	if err != nil {
		log.Fatalf("Error parsing events: %v\n", err)
	}

	log.Println("Finding data dependencies...")
	casolver.FindDataDependencies_All_Events(allEvents, dataList)

	outputResult(*output_file, orderedEvents)
	log.Println("Output saved to " + *output_file)
}
