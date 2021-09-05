import Event from './Event';

export default class SocketEvent extends Event {
  constructor(fields) {
    super(fields);
    this.channel = fields.socket;
    this.src = fields.src;
    this.src_port = fields.src_port;
    this.dst = fields.dst;
    this.dst_port = fields.dst_port;
    this.dependencies = fields.dependencies; // TODO
    this.size = fields.size;
    this.returned_value = fields.returned_value;
  }
}

