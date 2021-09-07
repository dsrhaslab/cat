import Event from './Event';
import SocketEvent from './SocketEvent';
import DiskEvent from './DiskEvent';

export default class EventFactory {
  static build(fields) {
    switch (fields.type) {
      case 'ACCEPT':
      case 'CONNECT':
      case 'SND':
      case 'RCV':
      case 'SHUTDOWN':
      case 'CLOSE':
        return new SocketEvent(fields);
      case 'WR':
      case 'RD':
      case 'OPEN':
        return new DiskEvent(fields);

      default:
        return new Event(fields);
    }
  }
}
