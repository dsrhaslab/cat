import ujson as json

class Event(object):
    def __init__(self, timestamp, type, thread, eventId, lineOfCode, order, dependency, dependencies, data=None):

        self._timestamp = timestamp
        self._type = type
        self._thread = thread
        self._eventId = eventId
        self._lineOfCode = lineOfCode
        self._order = order
        self._dependency = dependency
        self._dependencies = dependencies

        if data is not None:
            if 'comm' in data: self._comm = data['comm']
            if 'host' in data: self._host = data['host']
            if 'msg_len' in data: self._msg_len = data['msg_len']
            if 'msg' in data: self._msg = data['msg']
            if 'signature' in data: self._signature = data['signature']

        self._data_similarities = []
        self._color = '#000000'
        self._stroke = None

    def setPid(self, pid): self._pid = pid
    def setSocket(self, socket): self._socket = socket
    def setSocketType(self, socket_type): self._socket_type = socket_type
    def setSrc(self, src): self._src = src
    def setSrcPort(self, src_port): self._src_port = src_port
    def setDst(self, dst): self._dst = dst
    def setDstPort(self, dst_port): self._dst_port = dst_port
    def setSize(self, size): self._size = size
    def setReturnedValue(self, returned_value): self._returned_value = returned_value
    def setMessage(self, message): self._message = message
    def setFilename(self, filename): self._filename = filename
    def setFileDescriptor(self, fd): self._fd = fd
    def setOffset(self, offset): self._offset = offset

    def to_json(self):
        eventData = {
            "id": self._eventId,
            "type": self._type,
            "order": self._order,
            "timestamp": self._timestamp,
            "thread": self._thread,
            "dependency": self._dependency,
            "dependencies": self._dependencies,
            "loc": self._lineOfCode,
        }

        if hasattr(self, '_socket'): eventData['socket'] = self._socket
        if hasattr(self, '_socket_type'): eventData['socket_type'] = self._socket_type
        if hasattr(self, '_src'): eventData['src'] = self._src
        if hasattr(self, '_src_port'): eventData['src_port'] = self._src_port
        if hasattr(self, '_dst'): eventData['dst'] = self._dst
        if hasattr(self, '_dst_port'): eventData['dst_port'] = self._dst_port

        if hasattr(self, '_message'): eventData['message'] = self._message
        if hasattr(self, '_size'): eventData['size'] = self._size
        if hasattr(self, '_returned_value'): eventData['returned_value'] = self._returned_value
        if hasattr(self, '_filename'): eventData['filename'] = self._filename
        if hasattr(self, '_fd'): eventData['fd'] = self._fd
        if hasattr(self, '_offset'): eventData['offset'] = self._offset
        if hasattr(self, '_pid'): eventData['pid'] = self._pid

        data = {}
        if hasattr(self, '_comm'): data['comm'] = self._comm
        if hasattr(self, '_host'): data['host'] = self._host
        # if hasattr(self, '_msg'): data['msg'] = self._msg
        # if hasattr(self, '_msg_len'): data['msg_len'] = self._msg_len
        if hasattr(self, '_signature'): data['signature'] = self._signature
        if (len(data) > 0): eventData["data"] = data

        if self._data_similarities is not None: eventData["data_similarities"] = self._data_similarities

        return json.dumps(eventData)

    def to_string(self):
        eventData = {
            "id": self._eventId,
            "type": self._type,
            "order": self._order,
            "timestamp": self._timestamp,
            "thread": self._thread,
            "dependency": self._dependency,
            "dependencies": self._dependencies,
            "loc": self._lineOfCode,
        }

        if hasattr(self, '_socket'): eventData['socket'] = self._socket
        if hasattr(self, '_socket_type'): eventData['socket_type'] = self._socket_type
        if hasattr(self, '_src'): eventData['src'] = self._src
        if hasattr(self, '_src_port'): eventData['src_port'] = self._src_port
        if hasattr(self, '_dst'): eventData['dst'] = self._dst
        if hasattr(self, '_dst_port'): eventData['dst_port'] = self._dst_port

        if hasattr(self, '_message'): eventData['message'] = self._message
        if hasattr(self, '_size'): eventData['size'] = self._size
        if hasattr(self, '_returned_value'): eventData['returned_value'] = self._returned_value
        if hasattr(self, '_filename'): eventData['filename'] = self._filename
        if hasattr(self, '_fd'): eventData['fd'] = self._fd
        if hasattr(self, '_offset'): eventData['offset'] = self._offset
        if hasattr(self, '_pid'): eventData['pid'] = self._pid

        data = {}
        if hasattr(self, '_comm'): data['comm'] = self._comm
        if hasattr(self, '_host'): data['host'] = self._host
        # if hasattr(self, '_msg'): data['msg'] = self._msg
        # if hasattr(self, '_msg_len'): data['msg_len'] = self._msg_len
        if hasattr(self, '_signature'): data['signature'] = self._signature
        if (len(data) > 0): eventData["data"] = data

        if len(self._data_similarities) is not 0:
            eventData["data_similarities"] = { }
            for (e,s) in self._data_similarities:
                eventData["data_similarities"][e] = s

        return eventData

