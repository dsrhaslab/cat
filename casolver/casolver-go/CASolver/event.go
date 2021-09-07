package CASolver

type Data struct {
	Host      string   `json:"host,omitempty"`
	Comm      string   `json:"comm,omitempty"`
	Msg       string   `json:"-"`
	MsgLen    int64    `json:"-"`
	Signature []uint64 `json:"signature,omitempty"`
}

type Event struct {
	Order            int      `json:"order"`
	Id               int      `json:"id"`
	Timestamp        string   `json:"timestamp"`
	Etype            string   `json:"type"`
	Thread           string   `json:"thread"`
	Pid              uint32   `json:"pid,omitempty"`
	Loc              string   `json:"loc"`
	Dependency       *string  `json:"dependency"`
	Dependencies     []string `json:"dependencies"`
	Data             `json:"data,omitempty"`
	Src              string             `json:"src,omitempty"`
	Src_port         int                `json:"src_port,omitempty"`
	Dst              string             `json:"dst,omitempty"`
	Dst_port         int                `json:"dst_port,omitempty"`
	Socket           string             `json:"socket,omitempty"`
	Socket_type      string             `json:"socket_type,omitempty"`
	Message          string             `json:"message,omitempty"`
	Size             *int64             `json:"size,omitempty"`
	Returned_value   *int64             `json:"returned_value,omitempty"`
	Filename         string             `json:"filename,omitempty"`
	Fd               *int               `json:"fd,omitempty"`
	Offset           *int64             `json:"offset,omitempty"`
	DataSimilarities map[string]float64 `json:"data_similarities,omitempty"`
}
