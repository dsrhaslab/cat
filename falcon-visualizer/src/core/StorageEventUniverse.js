import EventFactory from './event/EventFactory';

const jsnx = require('jsnetworkx');
const goldenColors = require('golden-colors');

const eventsConstructor = Symbol('constructEvents');
const clusterThreadsByPid = Symbol('clusterThreadsByPid');
const filterUnrelevantThreads = Symbol('filterUnrelevantThreads');
const abcDict = 'ΑΒCDEFGHIJKLMNOPQRSTUVWXYZΓΔΘΛΞΠΣϒΦΧΨΩαβγδεζηθϑικλμνξοπϖρςστυφχψω';

export default class EventUniverse {

  constructor(data) {
    this.events = {};
    this.orderedEvents = [];
    this.orderedThreads = [];
    this[eventsConstructor](data);
    this.eventsSimilarityByColor(0.8);
    // this.eventsSimilarityBySymbol(0.8);
  }

  get count() {
    return Object.keys(this.events).length;
  }

  get maxClock() {
    return this.orderedEvents[this.orderedEvents.length - 1].clock;
  }

  at(clock) {
    return this.subset(clock, clock + 1);
  }

  subset(startClock, endClock) {
    return this.orderedEvents.filter(e => e.clock >= startClock && e.clock < endClock);
  }

  event(id) {
    return this.events[id] || null;
  }


  [eventsConstructor](data) {
    data.forEach((record) => {
      const event = EventFactory.build(record);
      const threadName = event.getThreadIdentifier();
      this.events[event.id] = event;
      this.orderedEvents.push(event);

      if (this.getThreadOrderedIndex(threadName) < 0) {
        this.orderedThreads.push({
          pid: event.pid,
          thread: event.thread,
        });
      }
    });
    this[clusterThreadsByPid]();
    // this[filterUnrelevantThreads]();
  }

  eventsClearColors() {
    Object.keys(this.events).forEach((eventID) => {
      const event = this.events[eventID];
      event.color = null;
      event.max_sim = { };
    });
  }

  eventsSimilarityBySymbol(minSim) {
    let letterIndex = 0;
    Object.keys(this.events).forEach((eventID) => {
      const event = this.events[eventID];
      if (event.type === 'RCV') {
        if (event.symbol == null) {
          event.symbol = abcDict[letterIndex];
          letterIndex += 1;
        }
        Object.keys(event.data_similarities).forEach((eID) => {
          if (eID === eventID) return;
          const e = this.events[eID];
          const similarity = event.data_similarities[eID];
          if ((e.symbol == null) && similarity >= minSim) {
            e.symbol = event.symbol;
            this.events[e.dependency].symbol = event.symbol;
            e.max_sim = { eventID, similarity };
          } else if ((e.max_sim != null) && (e.max_sim.similarity < similarity)) {
            e.symbol = event.symbol;
            this.events[e.dependency].symbol = event.symbol;
            e.max_sim = (eventID, similarity);
          } else if ((similarity > minSim) && e.symbol != null) {
            event.symbol = e.symbol;
            this.events[e.dependency].symbol = e.symbol;
            event.max_sim = (eID, similarity);
          }
        });
      }
    });
    // this[filterUnrelevantThreads]();
  }

  eventsSimilarityByColorOld(minSim) {
    const colorPatterns2 = ['#000000', '#FFFFFF'];
    Object.keys(this.events).forEach((eventID) => {
      const event = this.events[eventID];
      if (event.type === 'RCV') {
        if (event.data_similarities == null) {
          return;
        }
        if (event.color == null) {
          let subColor = '#000000';
          while (colorPatterns2.includes(subColor)) {
            subColor = goldenColors.getHsvGolden(0.3, 0.99).toHexString();
          }
          colorPatterns2.push(subColor);
          event.color = subColor;
        }
        Object.keys(event.data_similarities).forEach((eID) => {
          if (eID === eventID) return;
          const e = this.events[eID];
          const similarity = event.data_similarities[eID];
          if ((e.color == null) && similarity >= minSim) {
            e.color = event.color;
            this.events[e.dependency].color = event.color;
            e.max_sim = { eventID, similarity };
          } else if ((e.max_sim != null) && (e.max_sim.similarity < similarity)) {
            e.color = event.color;
            this.events[e.dependency].color = event.color;
            e.max_sim = (eventID, similarity);
          } else if ((similarity > minSim) && e.color != null) {
            event.color = e.color;
            this.events[e.dependency].color = e.color;
            event.max_sim = (eID, similarity);
          }
        });
      }
    });
    // this[filterUnrelevantThreads]();
  }

  eventsSimilarityByColor(minSim) {
    const colorPatterns2 = ['#000000', '#FFFFFF'];
    let letterIndex = 0;
    // Declare the graph
    const G = new jsnx.Graph();

    // Add events to graph
    Object.keys(this.events).forEach((eventID) => {
      G.addNode(eventID);
    });

    // Add edges between events with similarity >= minSim
    Object.keys(this.events).forEach((eventID) => {
      const event = this.events[eventID];
      // event.color = '#000000';
      const subColor = '#000000';
      // while (colorPatterns2.includes(subColor)) {
      //   subColor = goldenColors.getHsvGolden(0.9, 0.84).toHexString();
      // }
      event.color = subColor;
      event.symbol = null;
      // event.symbol = abcDict[letterIndex];
      // letterIndex += 1;

      if (event.type === 'RCV' || event.type === 'SND' || event.type === 'WR' || event.type === 'RD') {
        if (event.data_similarities == null) {
          return;
        }

        Object.keys(event.data_similarities).forEach((eID) => {
          const similarity = event.data_similarities[eID];
          if (similarity >= minSim) {
            G.addEdge(eventID, eID);
          }
        });
      }
    });

    // Get all subgraphs
    const listSubgraphs = [];
    const listVisitedNodes = [];
    Object.keys(this.events).forEach((node) => {
      if (listVisitedNodes.includes(node, 0)) return;
      const nodeNeighbors = jsnx.neighbors(G, node);
      if (nodeNeighbors.length === 0) return;
      nodeNeighbors.push(node);
      nodeNeighbors.sort();
      listSubgraphs.push(nodeNeighbors);
      nodeNeighbors.forEach((n) => {
        listVisitedNodes.push(n);
      });
    });


    listSubgraphs.forEach((subgraph) => {
      let subColor = '#000000';
      while (colorPatterns2.includes(subColor)) {
        subColor = goldenColors.getHsvGolden(0.78, 0.84).toHexString();
      }
      colorPatterns2.push(subColor);
      const symbol = abcDict[letterIndex];
      letterIndex += 1;
      subgraph.forEach((node) => {
        const event = this.events[node];
        event.color = subColor;
        event.symbol = symbol;
      });
    });

    Object.keys(this.events).forEach((eventID) => {
      const event = this.events[eventID];
      if (event.symbol == null) {
        event.symbol = abcDict[letterIndex];
        letterIndex += 1;
      }
    });
  }

  [clusterThreadsByPid]() {
    this.orderedThreads = this.orderedThreads.sort((a, b) => {
      // PIDs are the same, so we need to compare threads.
      if (a.pid === b.pid) {
        if (a.thread < b.thread) {
          return -1;
        }
        return a.thread === b.thread ? 0 : 1;
      }

      // If PIDs are different, then compare them.
      if (a.pid < b.pid) {
        return -1;
      }
      return a.pid === b.pid ? 0 : 1;
    });
  }

  [filterUnrelevantThreads]() {
    const filteredOrderedThreads = [];
    this.orderedThreads.forEach((thread) => {
      const threadEvents = this.orderedEvents.filter(orderedEvent =>
        thread.pid === orderedEvent.pid && thread.thread === orderedEvent.thread);

      if (threadEvents.findIndex(e => !['START', 'END'].includes(e.type)) < 0) {
        // No relevant events were found, so prevent thread and events to be drew.
        this.orderedEvents = this.orderedEvents.filter(e => !threadEvents.includes(e));
        console.log(`Discarding thread ${thread.pid}-${thread.thread}`);
      } else {
        // Save the thread.
        filteredOrderedThreads.push(thread);
      }
    });
    this.orderedThreads = filteredOrderedThreads;
  }

  getThreadOrderedIndex(name) {
    return this.orderedThreads.findIndex(t => t.thread === name);
  }
}

