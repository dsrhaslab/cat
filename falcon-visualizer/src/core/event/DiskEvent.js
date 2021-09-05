import Event from './Event';

export default class DiskEvent extends Event {
  constructor(fields) {
    super(fields);
    this.size = fields.size;
    this.returned_value = fields.returned_value;
    this.filename = fields.filename;
    this.fd = fields.fd;
    this.offset = fields.offset;
  }
}

