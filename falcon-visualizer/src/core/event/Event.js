export default class Event {
  constructor(fields) {
    this.id = fields.id;
    // this.pid = (fields.thread.split('@')[1]).split('.')[0];
    // this.thread = fields.thread.split('@')[0];
    // this.thread = fields.thread.split('.')[0];
    this.pid = fields.pid;
    this.clock = fields.order;
    this.dependency = fields.dependency || null; // TODO
    this.type = fields.type;
    this.data = fields.data || null;
    this.data_similarities = fields.data_similarities;
    // this.child = (fields.thread.split('@')[1]).split('.')[0] || null;

    this.buildThreadIdentifier(fields.thread);
  }

  hasDependency() {
    return this.dependency !== null;
  }

  getThreadIdentifier() {
    // return `${this.pid}||${this.thread}`;
    // return `${this.pid}`;
    // return `${this.pid}`;
    return `${this.thread}`;
  }

  buildThreadIdentifier(thread) {
    if (/^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/.test(thread)) {
      this.thread = thread.split('@')[0];
    } else {
      this.thread = thread.split('.')[0];
    }
  }

}
