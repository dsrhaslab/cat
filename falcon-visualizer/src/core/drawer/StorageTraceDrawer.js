import SVG from 'svg.js';
import SocketEvent from '../event/SocketEvent';
import DiskEvent from '../event/DiskEvent';

const topPadding = 20;
const threadPadding = 180;
const clockPadding = 22;
const eventRadius = 10;
const drawThreadTimeline = Symbol('drawThreadTimeline');
const drawClockEvents = Symbol('drawClockEvents');
const calculateThreadPosition = Symbol('calculateThreadPosition');
const calculateNextClockPosition = Symbol('calculateNextClockPosition');
const generateEventId = Symbol('generateEventId');
const generateDependencyId = Symbol('generateDependencyId');
const generateTimelineId = Symbol('generateTimelineId');
const backInTime = Symbol('backInTime');
const updateRunningTimelines = Symbol('updateRunningTimelines');
const generateThreadColor = Symbol('generateThreadColor');

const colorPatterns = ['#D32F2F', '#43A047', '#7B1FA2', '#1E88E5', '#7E57C2', '#C0CA33', '#8D6E63'].reverse();

let focusEShape = null;
let focusDShape = null;
let focusLine = null;
const simMethod = 0;

export default class TraceDrawer {
  constructor(drawing, universe) {
    this.elementsPerClock = {};
    this.drewThreads = [];
    this.closedThreads = [];
    this.drewClocks = 0;
    this.drawing = drawing;
    this.universe = universe;
    this.processColors = {};
  }

  /**
   * Magic happens here.
   */
  nextClock() {
    this[drawClockEvents](this.drewClocks);
    window.scrollTo(document.documentElement.scrollLeft, document.body.scrollHeight);
  }

  drawSimilarityInfo() {
    const clockPosition = this[calculateNextClockPosition]();
    // const rect = this.drawing.rect(2000, clockPosition).attr({ id: 'tooltipRect',
    // x: this.drewThreads.length * (threadPadding * 1.25) }).fill('#f9f6f7');
    const rect = this.drawing.rect(2000, clockPosition).attr({ id: 'tooltipRect', x: this.drewClocks * (clockPadding * 1.25) }).fill('#f9f6f7');
    this.drawing.text('').attr({ id: 'tooltip', visibility: 'hidden', x: rect.x() + 20, y: rect.y() + 100 }).fill();
  }

  updateDataSimilaritiesByColor(minSim) {
    this.universe.eventsClearColors();
    this.universe.eventsSimilarityByColor(minSim / 100);
    Object.keys(this.universe.events).forEach((eventID) => {
      const event = this.universe.events[eventID];
      const n1Shape = SVG.get(TraceDrawer[generateEventId](eventID));
      n1Shape.fill(event.color || '#000000');
      if ((event.type === 'RCV') & (event.dependency != null)) {
        const deShape = SVG.get(TraceDrawer[generateDependencyId](eventID, event.dependency));
        deShape.stroke({ color: event.color });
      }
    });
  }


  /**
   * Magic happens here.
   */
  previousClock() {
    this[backInTime]();
  }

  /**
   * Clear all events.
   */
  reset() {
    this.drewThreads = [];
    this.drewClocks = 0;
    this.drawing.clear();
  }
  /* eslint class-methods-use-this:
  ["error", { "exceptMethods":[
    "ShowSimOnMouseOver",
    "ShowDetailsOnMouseOverEvent",
    "FocusSimilarPair",
    "FocusSimilarEvent"
  ] }] */

  FocusSimilarPair(curTSpan, e1, e2) {
    curTSpan.mouseover(() => {
      curTSpan.font({ weight: 'bold' });
      const n1Shape = SVG.get(TraceDrawer[generateEventId](e1));
      const n2Shape = SVG.get(TraceDrawer[generateEventId](e2));
      const deShape = SVG.get(TraceDrawer[generateDependencyId](e2, e1));
      n1Shape.stroke({ width: 2 });
      n2Shape.stroke({ width: 2 });
      deShape.stroke({ width: 4, dasharray: '5,5' });
    });
    curTSpan.mouseout(() => {
      curTSpan.font({ weight: 'normal' });
      const n1Shape = SVG.get(TraceDrawer[generateEventId](e1));
      const n2Shape = SVG.get(TraceDrawer[generateEventId](e2));
      const deShape = SVG.get(TraceDrawer[generateDependencyId](e2, e1));
      n1Shape.stroke({ width: 0 });
      n2Shape.stroke({ width: 0 });
      deShape.stroke({ width: 2, dasharray: '0' });
    });
  }

  FocusSimilarEvent(curTSpan, e) {
    curTSpan.mouseover(() => {
      curTSpan.font({ weight: 'bold' });
      const n1Shape = SVG.get(TraceDrawer[generateEventId](e));
      n1Shape.stroke({ width: 2, dasharray: '5,5' });
    });
    curTSpan.mouseout(() => {
      curTSpan.font({ weight: 'normal' });
      const n1Shape = SVG.get(TraceDrawer[generateEventId](e));
      n1Shape.stroke({ width: 0 });
    });
  }

  ShowDetailsOnMouseOverEvent(eShape, event) {
    const tooltip = SVG.get('tooltip');
    const tooltipRect = SVG.get('tooltipRect');
    if (focusEShape != null) { focusEShape.stroke({ width: 0 }); }
    if (focusDShape != null) { focusDShape.stroke({ width: 0 }); }
    if (focusLine != null) { focusLine.stroke({ width: 2 }); }

    eShape.stroke({ width: 2 });
    focusEShape = eShape;

    tooltip.text((add) => {
      add.tspan('EVENT details:').newLine().attr({ 'font-weight': 'bold' });

      add.tspan(' ').newLine().dx(20);

      add.tspan(`Type: ${event.type}`).newLine();
      if (event.data && event.data.comm) { add.tspan(`Command: ${event.data.comm}`).newLine(); }
      add.tspan(`Pid: ${event.pid}`).newLine();
      if (event instanceof SocketEvent || event instanceof DiskEvent) {
        if (event instanceof SocketEvent) {
          add.tspan(`Source: ${event.src}:${event.src_port}`).newLine();
          add.tspan(`Destination: ${event.dst}:${event.dst_port}`).newLine();
        }

        if (event instanceof DiskEvent) {
          add.tspan(`[${event.fd}] Filename: ${event.filename}`)
          .attr({ lengthAdjust: 'spacing' })
          .newLine();
        }
        if (event.size != null) { add.tspan(`Size: ${event.size}`).newLine(); }
        if (event.returned_value != null) { add.tspan(`Returned value: ${event.returned_value}`).newLine(); }
        if (event.offset !== undefined) { add.tspan(`Offset: ${event.offset}`).newLine(); }

        if (event.data_similarities) {
          add.tspan(' ').newLine().dx(20);
          add.tspan('Events with similar data:').newLine();
          // add.tspan(`Pair of events: (${dependency}, ${event.id}) has`).newLine();
          const hundredList = [];
          const ninetyList = [];
          const eightyList = [];
          const seventyList = [];
          const sixtyList = [];

          Object.keys(event.data_similarities).forEach((eid) => {
            const sim = (event.data_similarities[eid] * 100);
            if (sim === 100) {
              hundredList.push({ e: eid, s: sim });
            } else if (sim >= 90) {
              ninetyList.push({ e: eid, s: sim });
            } else if (sim >= 80) {
              eightyList.push({ e: eid, s: sim });
            } else if (sim >= 70) {
              seventyList.push({ e: eid, s: sim });
            } else if (sim >= 60) {
              sixtyList.push({ e: eid, s: sim });
            }
          });

          if (hundredList.length > 0) {
            add.tspan(' ').newLine().dx(20);
            add.tspan('100% of resemblance with events: ').newLine().dx(20);
            add.tspan('- ').newLine().dx(40);
          }
          hundredList.forEach((pair) => {
            const curTSpan = add.tspan(` ${pair.e};`);
            this.FocusSimilarEvent(curTSpan, pair.e);
          });

          if (ninetyList.length > 0) {
            add.tspan(' ').newLine().dx(20);
            add.tspan('>= 90% of resemblance with events: ').newLine().dx(20);
            add.tspan('- ').newLine().dx(40);
          }
          ninetyList.forEach((pair) => {
            const curTSpan = add.tspan(` ${pair.e};`);
            this.FocusSimilarEvent(curTSpan, pair.e);
          });

          if (eightyList.length > 0) {
            add.tspan(' ').newLine().dx(20);
            add.tspan('>= 80% of resemblance with events: ').newLine().dx(20);
            add.tspan('- ').newLine().dx(40);
          }
          eightyList.forEach((pair) => {
            const curTSpan = add.tspan(` ${pair.e};`);
            this.FocusSimilarEvent(curTSpan, pair.e);
          });

          if (seventyList.length > 0) {
            add.tspan(' ').newLine().dx(20);
            add.tspan('>= 70% of resemblance with events: ').newLine().dx(20);
            add.tspan('- ').newLine().dx(40);
          }
          seventyList.forEach((pair) => {
            const curTSpan = add.tspan(` ${pair.e};`);
            this.FocusSimilarEvent(curTSpan, pair.e);
          });

          if (sixtyList.length > 0) {
            add.tspan(' ').newLine().dx(20);
            add.tspan('>= 60% of resemblance with events: ').newLine().dx(20);
            add.tspan('- ').newLine().dx(40);
          }
          sixtyList.forEach((pair) => {
            const curTSpan = add.tspan(` ${pair.e};`);
            this.FocusSimilarEvent(curTSpan, pair.e);
          });
        }
      }
    });
    tooltip.rebuild(true);
    const textBbox = tooltip.bbox();
    if ((eShape.cy() + textBbox.height) > tooltipRect.height()) {
      tooltip.move(tooltip.x(), tooltipRect.height() - textBbox.height - 5);
    } else {
      tooltip.move(tooltip.x(), eShape.cy());
    }
    tooltip.attr('visibility', 'visible');
  }

  ShowSimOnMouseOver(obj, eShape, dShape, event, dependency) {
    const tooltip = SVG.get('tooltip');
    const tooltipRect = SVG.get('tooltipRect');
    if (focusEShape != null) { focusEShape.stroke({ width: 0 }); }
    if (focusDShape != null) { focusDShape.stroke({ width: 0 }); }
    if (focusLine != null) { focusLine.stroke({ width: 2 }); }
    obj.stroke({ width: 4, color: event.color });
    eShape.stroke({ width: 2 });
    dShape.stroke({ width: 2 });
    focusEShape = eShape;
    focusDShape = dShape;
    focusLine = obj;

    tooltip.text((add) => {
      const dep = this.universe.events[dependency];
      add.tspan(`Pair of events SND(${dependency})-RCV(${event.id})`).newLine()
      .attr({ 'font-weight': 'bold' });
      add.tspan(' ').newLine();

      add.tspan(`Send of ${dep.returned_value} bytes`).newLine();
      add.tspan(`from ${dep.src}:${dep.src_port} to ${dep.dst}:${dep.dst_port}`).newLine().dx(20);
      add.tspan(`Receive of ${event.returned_value} bytes`).newLine();
      add.tspan(`from ${event.src}:${event.src_port} to ${event.dst}:${event.dst_port}`).newLine().dx(20);

      const hundredList = [];
      const ninetyList = [];
      const eightyList = [];
      const seventyList = [];
      const sixtyList = [];


      if (!event.data_similarities) return;

      add.tspan(' ').newLine();
      add.tspan('Pair of Events with similar data:').newLine();
      Object.keys(event.data_similarities).forEach((eid) => {
        if (eid === (event.id).toString()) { return; }
        const sim = (event.data_similarities[eid] * 100);
        if (this.universe.events[eid].dependency === null) return;
        if (sim === 100) {
          hundredList.push({ e1: this.universe.events[eid].dependency, e2: eid, s: sim });
        } else if (sim >= 90) {
          ninetyList.push({ e1: this.universe.events[eid].dependency, e2: eid, s: sim });
        } else if (sim >= 80) {
          eightyList.push({ e1: this.universe.events[eid].dependency, e2: eid, s: sim });
        } else if (sim >= 70) {
          seventyList.push({ e1: this.universe.events[eid].dependency, e2: eid, s: sim });
        } else if (sim >= 60) {
          sixtyList.push({ e1: this.universe.events[eid].dependency, e2: eid, s: sim });
        }
      });

      if (hundredList.length > 0) {
        add.tspan(' ').newLine().dx(20);
        add.tspan('100% of resemblance with pairs: ').newLine().dx(20);
      }
      hundredList.forEach((pair) => {
        const curTSpan = add.tspan(`- (${pair.e1}, ${pair.e2})`).newLine().dx(40);
        this.FocusSimilarPair(curTSpan, pair.e1, pair.e2);
      });

      if (ninetyList.length > 0) {
        add.tspan(' ').newLine().dx(20);
        add.tspan('>= 90% of resemblance with pairs: ').newLine().dx(20);
      }
      ninetyList.forEach((pair) => {
        const curTSpan = add.tspan(`- (${pair.e1}, ${pair.e2}) => ${pair.s}%`).newLine().dx(40);
        this.FocusSimilarPair(curTSpan, pair.e1, pair.e2);
      });

      if (eightyList.length > 0) {
        add.tspan(' ').newLine().dx(20);
        add.tspan('>= 80% of resemblance with pairs: ').newLine().dx(20);
      }
      eightyList.forEach((pair) => {
        const curTSpan = add.tspan(`- (${pair.e1}, ${pair.e2}) => ${pair.s}%`).newLine().dx(40);
        this.FocusSimilarPair(curTSpan, pair.e1, pair.e2);
      });

      if (seventyList.length > 0) {
        add.tspan(' ').newLine().dx(20);
        add.tspan('>= 70% of resemblance with pairs: ').newLine().dx(20);
      }
      seventyList.forEach((pair) => {
        const curTSpan = add.tspan(`- (${pair.e1}, ${pair.e2}) => ${pair.s}%`).newLine().dx(40);
        this.FocusSimilarPair(curTSpan, pair.e1, pair.e2);
      });

      if (sixtyList.length > 0) {
        add.tspan(' ').newLine().dx(20);
        add.tspan('>= 60% of resemblance with pairs: ').newLine().dx(20);
      }
      sixtyList.forEach((pair) => {
        const curTSpan = add.tspan(`- (${pair.e1}, ${pair.e2}) => ${pair.s}%`).newLine().dx(40);
        this.FocusSimilarPair(curTSpan, pair.e1, pair.e2);
      });
    });
    tooltip.rebuild(true);
    const textBbox = tooltip.bbox();
    if ((obj.cy() + textBbox.height) > tooltipRect.height()) {
      tooltip.move(tooltip.x(), tooltipRect.height() - textBbox.height - 5);
    } else {
      tooltip.move(tooltip.x(), obj.y());
    }
    tooltip.attr('visibility', 'visible');
  }

  [drawThreadTimeline](thread, clockPosition = 0, color) {
    if (this.drewThreads.includes(thread)) {
      return this[calculateThreadPosition](thread);
    }

    this.drewThreads.push(thread);
    const threadPosition = this[calculateThreadPosition](thread);
    this.drawing.width(this.drewThreads.length * (threadPadding * 6));
    const threadLineY1 = clockPosition > 0 ? clockPosition : clockPosition + topPadding;
    const threadLineY2 = threadLineY1 + (topPadding / 2);
    console.log(threadLineY1, threadPosition, threadLineY2, threadPosition);
    // this.drawing.line(threadPosition, threadLineY1, threadPosition, threadLineY2)
    this.drawing.line(0, threadPosition - (topPadding * 2.5),
    threadLineY1, threadPosition + threadLineY2)
        .stroke({ width: 1, color: color || '#000000' })
        .attr({ 'stroke-dasharray': '5, 5' })
        .id(TraceDrawer[generateTimelineId](thread));

    // const threadLabel=this.drawing.plain(thread.split('||')[0]).font({ fill: color||'#000000' });
    // const threadLabel = this.drawing.plain(thread).font({ fill: color || '#000000' });
    // const threadLabelBox = threadLabel.bbox();
    // threadLabel.move(threadPosition - threadLabelBox.cx, 0);

    return threadPosition;
  }

  [drawClockEvents](clock) {
    const events = this.universe.at(clock);
    const clockPosition = this[calculateNextClockPosition]();

    // Draw clock label.
    this.drawing.width(clockPosition + clockPadding);
    const clockLabel = this.drawing.plain(`${clock}`);
    const clbb = clockLabel.bbox();
    console.log(clbb.width);
    clockLabel.move((clockPosition + ((eventRadius / 2) - (clbb.width / 2))), 0);

    events.forEach((event) => {
      const eventGroup = this.drawing.group();
      // Draw a new timeline if the thread does not exist and get its position.
      // const threadColor = this[generateThreadColor](event.pid);
      const threadColor = '#000000';
      const threadPosition = this[drawThreadTimeline](event.getThreadIdentifier(), event.type === 'START' ? clockPosition : 0, threadColor);

      // Draw event.
      const eventShape = eventGroup.rect(eventRadius * 1.5, eventRadius * 4)
        .fill(event.color || '#000000')
        // .move(threadPosition - eventRadius, clockPosition - eventRadius)
        .move(clockPosition - (eventRadius / 4), threadPosition - (eventRadius * 7))
        .id(TraceDrawer[generateEventId](event.id));

      const eventIDLabel = eventGroup.plain(`${event.symbol}`).font({ size: 13 }).fill('#FFFFFF');
      const bb = eventIDLabel.bbox();
      eventIDLabel.attr('x', (clockPosition + (eventRadius / 3)) - (bb.height / 4));
      eventIDLabel.attr('y', (threadPosition - (topPadding * 2.5)) + (bb.height / 3));


      const eventShapeBox = eventShape.bbox();
      // const eventLabel = eventGroup.plain(`${event.type}`);
      // eventLabel.move(eventShapeBox.x + (3 * eventRadius),
      // eventShapeBox.y - ((eventRadius - eventLabel.font('size')) / 2));
      // eventLabel.move(eventShapeBox.x + (eventRadius * 13),
      // eventShapeBox.y - ((eventRadius) / 2));

      eventShape.mouseover(() => {
        this.ShowDetailsOnMouseOverEvent(eventShape, event);
      });

      if (event.type === 'LOG') {
        const titleMessage = eventGroup.element('title').words(event.data.data.message);
        titleMessage.addTo(eventGroup);
      }

      // Draw connector.
      let dependencies = [];
      if (event.hasDependency()) {
        if (['SND', 'RCV'].includes(event.type)) {
          dependencies = event.dependencies;
        } else {
          dependencies.push(event.dependency);
        }
      }

      dependencies.forEach((dependency) => {
        const dependencyShape = SVG.get(TraceDrawer[generateEventId](dependency));
        const dependencyShapeBox = dependencyShape.bbox();
        const connectorShape = this.drawing.line(
          dependencyShapeBox.cx, dependencyShapeBox.cy,
          dependencyShapeBox.cx, dependencyShapeBox.cy,
        ).id(TraceDrawer[generateDependencyId](event.id, dependency)).addClass('dependency').addClass(event.id)
        .addClass(dependency)
        //  .stroke({ width: 2, color: '#000000' })
         .stroke({ width: 2, color: event.color || '#000000' })
         .mouseover(() => {
           this.ShowSimOnMouseOver(connectorShape, eventShape, dependencyShape, event, dependency);
         });

        const eventDependency = this.universe.events[dependency];
        if (event.color === eventDependency.color) {
          connectorShape.stroke({ width: 2, color: event.color });
        }

        if ((simMethod === 1) && (event.symbol)) {
          const xcor = (dependencyShapeBox.x + eventShapeBox.x) / 2;
          this.drawing.plain(event.symbol)
          .move(xcor, ((dependencyShapeBox.y + eventShapeBox.y) / 2) - 15);
        }

        connectorShape.attr({ x2: eventShapeBox.cx, y2: eventShapeBox.cy });
        connectorShape.back();
      });

      // Update Timeline.
      const timelineShape = SVG.get(TraceDrawer[generateTimelineId](event.getThreadIdentifier()));
      timelineShape.attr({ x2: eventShapeBox.cx, y2: eventShapeBox.cy });

      if (event.type === 'END') {
        this.closedThreads.push(event.getThreadIdentifier());
      }

      this[updateRunningTimelines](eventShapeBox.cy);
    });

    this.drewClocks += 1;
  }

  [backInTime]() {
    // TODO: Remove elements in a single clock.
    console.log(this);
  }

  [updateRunningTimelines](y) {
    this.drewThreads
      .filter(thread => !this.closedThreads.includes(thread))
      .forEach((thread) => {
        const timelineShape = SVG.get(TraceDrawer[generateTimelineId](thread));
        timelineShape.attr({ y2: y });
      });
  }

  static [calculateThreadPosition](index) {
    return (index * threadPadding) + (threadPadding / 2);
  }

  [calculateThreadPosition](thread) {
    const index = this.universe.getThreadOrderedIndex(thread);
    return index >= 0 ? TraceDrawer[calculateThreadPosition](index) : null;
  }

  [calculateNextClockPosition]() {
    return topPadding + (this.drewClocks * clockPadding) + (clockPadding / 2);
  }

  static [generateEventId](eventId) {
    return `event${eventId}`;
  }

  static [generateDependencyId](eventId, dependencyId) {
    return `dependency${eventId}${dependencyId}`;
  }

  static [generateTimelineId](eventId) {
    return `timeline${eventId}`;
  }

  /* eslint no-bitwise: 0 */
  /* eslint no-restricted-syntax: 1 */
  [generateThreadColor](threadId) {
    if (this.processColors[threadId] === undefined) {
      this.processColors[threadId] = colorPatterns.pop();
    }

    return this.processColors[threadId];

    // let hash = 0;
    // let color = '#';
    // const id = `${threadId}`;

    // for (const char of id) {
    //   hash = char.charCodeAt(0) + ((hash << 5) - hash);
    // }

    // for (let i = 0; i < 3; i += 1) {
    //   const value = (hash >> (i * 8)) & 0xFF;
    //   color += (`00${value.toString(16)}`).substr(-2);
    // }
    // console.log(color);
    // return color;
  }
}
