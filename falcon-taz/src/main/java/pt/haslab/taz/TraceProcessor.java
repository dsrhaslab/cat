package pt.haslab.taz;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.SortedSet;
import java.util.TreeSet;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONTokener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import pt.haslab.taz.causality.CausalPair;
import pt.haslab.taz.causality.MessageCausalPair;
import pt.haslab.taz.events.*;
import pt.haslab.taz.utils.Utils;

/**
 * The class is responsible for parsing an event trace and organize the events into different data structures
 * according to their type.
 * Created by nunomachado on 05/03/18.
 */
public enum TraceProcessor
{
    /* TraceProcessor is a singleton class implemented using the single-element enum type approach */
    INSTANCE;

    private static Logger logger = LoggerFactory.getLogger( TraceProcessor.class );

    /* counts the number of events in the trace */
    private int eventNumber = 0;

    /* Map: message id -> pair of events (snd,rcv) */
    public Map<String, MessageCausalPair> sndRcvPairs;

    /* Counter representing the message id for traces from TCP connections.
       The message id is increased whenever a pair (snd,rcv) is complete */
    private long tcpMessageId = 0;

    /* Map: rcv event-> list of events of the message handler
     * (list starts with HANDLERBEGIN and ends with HANDLEREND) */
    public Map<SocketEvent, List<Event>> handlerEvents;

    /* set indicating whether a given thread's trace has message handlers */
    private HashSet hasHandlers;

    /* Map: socket id -> pair of events (connect,accept) */
    public Map<String, CausalPair<SocketEvent, SocketEvent>> connAcptEvents;

    /* Map: socket id -> pair of events (close,shutdown) */
    public Map<String, CausalPair<SocketEvent, SocketEvent>> closeShutEvents;

    /* Map: thread -> list of all events in that thread's execution ordered by timestamp */
    public Map<String, SortedSet<Event>> eventsPerThread;

    /* Map: thread -> list of thread's fork events */
    public Map<String, List<ThreadCreationEvent>> forkEvents;

    /* Map: thread -> list of thread's join events */
    public Map<String, List<ThreadCreationEvent>> joinEvents;

    /* Map: mutex variable -> list of pairs of locks/unlocks */
    public Map<String, List<CausalPair<SyncEvent, SyncEvent>>> lockEvents;

    /* Map: variable -> list of reads to that variable by all threads */
    public Map<String, List<RWEvent>> readEvents;

    /* Map: variable -> list of writes to that variable by all threads */
    public Map<String, List<RWEvent>> writeEvents;

    /* Map: condition variable -> list of thread's wait events */
    public Map<String, List<SyncEvent>> waitEvents;

    /* Map: condition variable -> list of thread's notify events */
    public Map<String, List<SyncEvent>> notifyEvents;

    /* list with socket events ordered by timestamp */
    public SortedSet<Event> sortedByTimestamp;

    //local variables (only used during parsing, but not necessary afterwards)
    /* Map: socket channel -> pair of event lists ([snd],[rcv]) */
    private Map<String, CausalPair<Deque<SocketEvent>, Deque<SocketEvent>>> pendingEventsSndRcv;

    private boolean groupByHost = false;

    TraceProcessor()
    {
        sndRcvPairs = new HashMap<String, MessageCausalPair>();
        lockEvents = new HashMap<String, List<CausalPair<SyncEvent, SyncEvent>>>();
        eventsPerThread = new HashMap<String, SortedSet<Event>>();
        readEvents = new HashMap<String, List<RWEvent>>();
        writeEvents = new HashMap<String, List<RWEvent>>();
        forkEvents = new HashMap<String, List<ThreadCreationEvent>>();
        joinEvents = new HashMap<String, List<ThreadCreationEvent>>();
        waitEvents = new HashMap<String, List<SyncEvent>>();
        notifyEvents = new HashMap<String, List<SyncEvent>>();
        connAcptEvents = new HashMap<String, CausalPair<SocketEvent, SocketEvent>>();
        closeShutEvents = new HashMap<String, CausalPair<SocketEvent, SocketEvent>>();
        sortedByTimestamp = new TreeSet<Event>( new TimestampComparator() );
        pendingEventsSndRcv = new HashMap<String, CausalPair<Deque<SocketEvent>, Deque<SocketEvent>>>();
        handlerEvents = new HashMap<SocketEvent, List<Event>>();
        hasHandlers = new HashSet();
    }

    /**
     * This method parses the events of an execution trace passed as input and organizes them into
     * different data structures according to their type.
     *
     * @param pathToFile an absolute path giving the location of the event trace.
     * @return void
     * @throws JSONException
     * @throws IOException
     */
    public void loadEventTrace( String pathToFile, boolean groupByHost )
            throws JSONException, IOException
    {

        logger.info( "Loading events from " + pathToFile );
        this.groupByHost = groupByHost;
        try
        {
            // Parse the event trace as JSON Array.
            JSONTokener tokener = new JSONTokener( new FileReader( pathToFile ) );
            JSONArray jsonevents = new JSONArray( tokener );

            for ( int i = 0; i < jsonevents.length(); i++ )
            {
                JSONObject object = jsonevents.getJSONObject( i );
                parseJSONEvent( object );
            }
        }
        catch ( JSONException e )
        {
            String msg = e.getMessage();

            if ( msg.startsWith( "A JSONArray text must start" ) )
            {
                // Parse events as JSON Objects.
                logger.error( "Load as JSONArray failed. Try loading as file of JSONObjects" );
                BufferedReader br = new BufferedReader( new FileReader( pathToFile ) );
                String line = br.readLine();
                while ( line != null )
                {
                    try
                    {
                        JSONObject object = new JSONObject( line );
                        parseJSONEvent( object );
                    }
                    catch ( JSONException objError )
                    {
                        if ( objError.getMessage().contains( "event type" ) )
                        {
                            logger.error( objError.getMessage() );
                        }
                        else
                        {
                            logger.error( "Invalid JSON: " + line );
                        }
                    }
                    finally
                    {
                        line = br.readLine();
                    }
                }
            }
            else
            {
                throw e;
            }
        }
        finally
        {
            if ( !hasHandlers.isEmpty() )
            {
                parseMessageHandlers();
            }
        }

        if ( logger.isDebugEnabled() )
        {
            printDataStructures();
        }
        logger.info( "Trace successfully loaded!" );

    }

    /**
     * This method receives a JSON object read from the event trace and builds an object of type Event (or subclass of
     * Event). Next, the method inserts the object Event into the respective data structures according to its
     * type.
     *
     * @param event a JSON object representing an execution event to be parsed.
     * @return void
     * @throws JSONException
     */
    private void parseJSONEvent( JSONObject event )
            throws JSONException
    {
        /* --- Parse required fields --- */

        // Check whether the type of the event is encoded as an integer value or a string.
        String typeField = event.getString( "type" );
        EventType type = null;
        if ( Character.isDigit( typeField.charAt( 0 ) ) )
        {
            type = EventType.getEventType( Integer.valueOf( typeField ) );
        }
        else
        {
            type = EventType.getEventType( typeField );
        }

        if ( type == null )
            throw new JSONException( "Unknown event type: " + event.getString( "type" ) );

        String thread = event.getString("thread");
        if (groupByHost) thread = thread.split("@")[1];

        String loc = event.optString( "loc" );
        loc = ( loc == null ) ? "" : loc;

        // Consider timestamp to be a long for the moment.
        long time = event.getLong( "timestamp" );
        String timestamp = String.valueOf( time );

        /* --- Parse optional fields --- */
        // Use the event id in the JSON object, if present, or the global event counter, otherwise.
        long eventId = event.has( "id" ) ? event.getLong( "id" ) : eventNumber++;
        Event e = new Event( timestamp, type, thread, eventId, loc );

        if ( event.has( "pid" ) )
            e.setPid(event.getInt("pid"));

        String dependency = event.optString( "dependency" );
        if ( dependency.length() == 0 || dependency.equals( "null" ) )
            dependency = null;
        e.setDependency( dependency );
        if ( event.has( "data" ) )
            e.setData( event.optJSONObject( "data" ) );

        // Create a new thread event timeline.
        if ( !eventsPerThread.containsKey( thread ) )
        {
            eventsPerThread.put( thread, new TreeSet<Event>( new TimestampComparator() ) );
        }

        // Populate the data structures according to the event type.
        switch ( type )
        {
            case LOG:
                String msg = event.getString( "message" );
                LogEvent logEvent = new LogEvent( e, msg );
                eventsPerThread.get( thread ).add( logEvent );
                sortedByTimestamp.add( logEvent );
                break;
            case DISKWRITE:
            case DISKREAD:
            case DISKOPEN:
                DiskEvent diskEvent = new DiskEvent( e );
                if ( event.has( "size" ) )
                    diskEvent.setSize( event.getInt( "size" ) );
                if ( event.has( "fd" ) )
                    diskEvent.setFileDescriptor( event.getLong( "fd" ) );
                if ( event.has( "offset" ) )
                    diskEvent.setOffset( event.getLong( "offset" ) );
                if ( event.has( "filename" ) )
                    diskEvent.setFilename( event.getString( "filename" ) );
                if ( event.has( "returned_value" ) )
                    diskEvent.setReturnedValue( event.getInt( "returned_value" ) );
                eventsPerThread.get( thread ).add( diskEvent );
                sortedByTimestamp.add( diskEvent );
                break;

            case CONNECT:
            case ACCEPT:
            case CLOSE:
            case SHUTDOWN:
            case RCV:
            case SND:
                SocketEvent socketEvent = new SocketEvent( e );

                // Build SocketEvent by setting the required fields.
                String socketChannelId = event.getString( "socket" );
                socketEvent.setSocket( socketChannelId );
                socketEvent.setSocketType( event.getString( "socket_type" ) );
                socketEvent.setSrc( event.getString( "src" ) );
                socketEvent.setSrcPort( event.getInt( "src_port" ) );
                socketEvent.setDst( event.getString( "dst" ) );
                socketEvent.setDstPort( event.getInt( "dst_port" ) );

                // Handle SND and RCV events.
                if ( type == EventType.SND || type == EventType.RCV )
                {
                    socketEvent.setSize( event.getInt( "size" ) );
                    socketEvent.setReturnedValue( event.getInt( "returned_value" ) );

                    socketEvent.setMessageId( event.optString( "message", null ) );

                    // Handle UDP cases by matching the message id.
                    if ( socketEvent.getSocketType() == SocketEvent.SocketType.UDP )
                    {
                        // Update existing message causal pair or create a new one if necessary.
                        sndRcvPairs.putIfAbsent(socketEvent.getMessageId(), new MessageCausalPair());
                        MessageCausalPair msgCausalPair = sndRcvPairs.get( socketEvent.getMessageId() );

                        if ( type == EventType.SND )
                        {
                            msgCausalPair.addSnd( socketEvent );
                        }
                        else
                        {
                            msgCausalPair.addRcv( socketEvent );
                        }

                    }

                    // Handle TCP cases by matching the amount of bytes sent with those received.
                    else if ( socketEvent.getSocketType() == SocketEvent.SocketType.TCP )
                    {
                        if ( type == EventType.SND )
                        {
                            handleSndSocketEvent( socketEvent );
                        }

                        if ( type == EventType.RCV )
                        {
                            handleRcvSocketEvent( socketEvent );
                        }
                    }
                }
                // Handle CONNECT and ACCEPT events.
                else if ( type == EventType.CONNECT || type == EventType.ACCEPT )
                {
                    // Update existing causal pair or create a new one if necessary.
                    if ( !connAcptEvents.containsKey( socketChannelId ) )
                    {
                        connAcptEvents.put( socketChannelId, new CausalPair<SocketEvent, SocketEvent>( null, null ) );
                    }

                    CausalPair<SocketEvent, SocketEvent> connAccPair = connAcptEvents.get( socketChannelId );

                    // The CONNECT is the first element of the causal pair.
                    if ( type == EventType.CONNECT )
                    {
                        connAccPair.setFirst( socketEvent );
                    }
                    // The ACCEPT is the second element of the causal pair.
                    else
                    {
                        connAccPair.setSecond( socketEvent );
                    }
                }

                // Handle CLOSE and SHUTDOWN.
                else if ( type == EventType.CLOSE || type == EventType.SHUTDOWN )
                {
                    // Update existing causal pair or create a new one if necessary.
                    if ( !closeShutEvents.containsKey( socketChannelId ) )
                    {
                        closeShutEvents.put( socketChannelId, new CausalPair<SocketEvent, SocketEvent>( null, null ) );
                    }

                    CausalPair<SocketEvent, SocketEvent> closeShutPair = closeShutEvents.get( socketChannelId );

                    // The SHUTDOWN event is the second element of the causal pair.
                    if ( closeShutPair.getSecond() == null && type == EventType.SHUTDOWN )
                    {
                        closeShutPair.setSecond( socketEvent );
                    }
                    else
                    {
                        /*
                         *  The CLOSE event is the first element of the causal pair.
                         *  If there's already a CLOSE event in the pair, overwrite it if the SHUTDOWN is from
                         *  another thread.
                         */
                        SocketEvent closeEvent = closeShutPair.getFirst();
                        SocketEvent shutdownEvent = closeShutPair.getSecond();
                        if ( closeEvent == null
                                || ( shutdownEvent != null && !shutdownEvent.getThread().equals(
                                socketEvent.getThread() ) ) )
                        {
                            closeShutPair.setFirst( socketEvent );
                        }
                    }
                }

                eventsPerThread.get( thread ).add( socketEvent );
                sortedByTimestamp.add( socketEvent );
                break;

            case START:
            case END:
                if (!groupByHost) eventsPerThread.get( thread ).add( e );
//                sortedByTimestamp.add(e);
                break;

            case CREATE:
            case JOIN:
                if (!groupByHost) {
                    ThreadCreationEvent creationEvent = new ThreadCreationEvent(e);

                    // Build ThreadCreationEvent by setting the required fields.
                    String child = event.getString("child");
                    creationEvent.setChildThread(child);

                    if (type == EventType.CREATE) {
                        if (!forkEvents.containsKey(thread)) {
                            forkEvents.put(thread, new LinkedList<ThreadCreationEvent>());
                        }
                        forkEvents.get(thread).add(creationEvent);
                    } else {
                        if (!joinEvents.containsKey(thread)) {
                            joinEvents.put(thread, new LinkedList<ThreadCreationEvent>());
                        }
                        joinEvents.get(thread).add(creationEvent);
                    }
                    eventsPerThread.get(thread).add(creationEvent);
                }
                sortedByTimestamp.add(e);
                break;

            case WRITE:
            case READ:
                RWEvent rwEvent = new RWEvent( e );

                // Build RWEvent by setting the required fields.
                String variable = event.getString( "variable" );
                rwEvent.setVariable( variable );

                if ( type == EventType.READ )
                {
                    if ( !readEvents.containsKey( variable ) )
                    {
                        readEvents.put( variable, new LinkedList<RWEvent>() );
                    }
                    readEvents.get( variable ).add( rwEvent );
                }
                else
                {
                    if ( !writeEvents.containsKey( variable ) )
                    {
                        writeEvents.put( variable, new LinkedList<RWEvent>() );
                    }
                    writeEvents.get( variable ).add( rwEvent );
                }
                eventsPerThread.get( thread ).add( rwEvent );
                sortedByTimestamp.add( rwEvent );
                break;

            case HNDLBEG:
            case HNDLEND:
                HandlerEvent handlerEvent = new HandlerEvent( e );
                eventsPerThread.get( thread ).add( handlerEvent );
                if ( type == EventType.HNDLBEG )
                    hasHandlers.add( thread );
                sortedByTimestamp.add( handlerEvent );
                break;

            case LOCK:
            case UNLOCK:
                SyncEvent lockEvent = new SyncEvent( e );

                // Build SyncEvent by setting the required fields.
                String lockVariable = event.getString( "variable" );
                lockEvent.setVariable( lockVariable );

                // Get the last locking pair on lockVariable, if any.
                List<CausalPair<SyncEvent, SyncEvent>> pairList = lockEvents.get( lockVariable );
                CausalPair<SyncEvent, SyncEvent> lockPair =
                        ( pairList != null ) ? pairList.get( pairList.size() - 1 ) : null;

                if ( type == EventType.LOCK )
                {
                    if ( lockPair == null || lockPair.getSecond() != null )
                    {
                        /*
                         * In order to handle reentrant locks, add the LOCK event only
                         * if the last lock pair has a corresponding UNLOCK.
                         */
                        Utils.insertInMapToLists( lockEvents, lockVariable,
                                new CausalPair<SyncEvent, SyncEvent>( lockEvent, null ) );
                        eventsPerThread.get( thread ).add( lockEvent );
                    }
                }
                else   // type == EventType.UNLOCK
                {
                    if ( lockPair == null )
                    {
                        Utils.insertInMapToLists( lockEvents, lockVariable,
                                new CausalPair<SyncEvent, SyncEvent>( null, lockEvent ) );
                    }
                    else
                    {
                        lockPair.setSecond( lockEvent );
                    }
                    eventsPerThread.get( thread ).add( lockEvent );
                }
                sortedByTimestamp.add( lockEvent );
                break;

            case NOTIFY:
            case NOTIFYALL:
            case WAIT:
                SyncEvent syncEvent = new SyncEvent( e );
                String syncVariable = event.getString( "variable" );
                syncEvent.setVariable( syncVariable );

                if ( type == EventType.WAIT )
                {
                    if ( !waitEvents.containsKey( syncVariable ) )
                    {
                        waitEvents.put( syncVariable, new LinkedList<SyncEvent>() );
                    }
                    waitEvents.get( syncVariable ).add( syncEvent );
                }
                else if ( type == EventType.NOTIFY || type == EventType.NOTIFYALL )
                {
                    if ( !notifyEvents.containsKey( syncVariable ) )
                    {
                        notifyEvents.put( syncVariable, new LinkedList<SyncEvent>() );
                    }
                    notifyEvents.get( syncVariable ).add( syncEvent );
                }
                eventsPerThread.get( thread ).add( syncEvent );
                sortedByTimestamp.add( syncEvent );
                break;

            default:
                throw new JSONException( "Unknown event type: " + type );
        }
    }

    /**
     * Re-iterates through the trace to compute the list of events corresponding to each RCV's message handler.
     *
     * @return void
     */
    private void parseMessageHandlers()
    {
        for ( String thread : eventsPerThread.keySet() )
        {

            // Only check threads that actually have message handlers.
            if ( !hasHandlers.contains( thread ) || eventsPerThread.get( thread ).size() <= 1 )
                continue;

            // Use a fast and a slow iterator to handle nested message handlers while iterating through the thread events.
            SortedSet<Event> threadEvents = eventsPerThread.get( thread );
            Iterator<Event> slowIt = threadEvents.iterator();
            Iterator<Event> fastIt = threadEvents.iterator();

            while( slowIt.hasNext() )
            {
                Event e = slowIt.next();
                fastIt.next(); // advance fastIt to follow slowIt

                // A message handler occurs when there is a HANDLERBEGIN event after a RCV event.
                Event nextEvent = slowIt.next();
                if ( e.getType() == EventType.RCV && nextEvent !=null && nextEvent.getType() == EventType.HNDLBEG )
                {
                    List<Event> handlerList = new ArrayList<Event>();
                    nextEvent = fastIt.next();
                    int nestedCounter = 0;

                    // Add events to the message handler until reaching the HANDLEREND delimiter.
                    while ( nextEvent != null
                            && nextEvent.getType() != EventType.HNDLEND
                            && nestedCounter >= 0
                            && fastIt.hasNext() )
                    {
                        handlerList.add( nextEvent );

                        // Initiate a new (nested) handler if HANDLERBEGIN is found during the iteration.
                        if ( nextEvent.getType() == EventType.HNDLBEG )
                        {
                            nestedCounter++;
                        }
                        else if ( nextEvent.getType() == EventType.HNDLEND )
                        {
                            nestedCounter--; //last HANDLEREND will set nestedCounter to -1 and end the loop
                        }

                        nextEvent = fastIt.next();
                    }
                    handlerList.add( nextEvent ); //add HANDLEREND event
                    handlerEvents.put( (SocketEvent) e, handlerList );
                }
            }
        }
    }

    /**
     * Returns the total number of events in the trace.
     *
     * @return the total number of events in the trace.
     */
    public int getNumberOfEvents()
    {
        return eventNumber;
    }

    /**
     * Given the identifier of a socket channel, the method returns a queue with SND events
     * (respectively RCV events) waiting to be matched with RCV events (respectively SND events) on the same channel.
     * If no such queue exists, the method creates and returns a new empty one.
     *
     * @param socketChannelId the identifier of a socket channel between two processes that exchange messages.
     * @return the pair of queues with pending SND or RCV events.
     */
    private CausalPair<Deque<SocketEvent>, Deque<SocketEvent>> getOrCreatePartialEventsPairs( String socketChannelId )
    {
        if ( !pendingEventsSndRcv.containsKey( socketChannelId ) )
        {
            Deque<SocketEvent> sndEvents = new ArrayDeque<SocketEvent>();
            Deque<SocketEvent> rcvEvents = new ArrayDeque<SocketEvent>();
            CausalPair<Deque<SocketEvent>, Deque<SocketEvent>> pendingEventsPair =
                    new CausalPair<Deque<SocketEvent>, Deque<SocketEvent>>( sndEvents, rcvEvents );

            pendingEventsSndRcv.put( socketChannelId, pendingEventsPair );

            return pendingEventsPair;
        }

        return pendingEventsSndRcv.get( socketChannelId );
    }

    /**
     * For an incoming SND event, the method attempts to pair it with existing RCV events in the pending queue. Since the
     * size (in bytes) of the SND and the existing RCV events may not be even, the method iteratively pops pending RCV
     * events until matching the full amount of bytes sent. If there are no pending RCV events, the method adds the
     * incoming SND to the queue of pending SND events.
     *
     * @param snd a SND event parsed from the event trace.
     * @return void
     */
    private void handleSndSocketEvent( SocketEvent snd )
    {
        CausalPair<Deque<SocketEvent>, Deque<SocketEvent>> pendingSndRcvEvents = getOrCreatePartialEventsPairs( snd.getDirectedSocket() );
        Deque<SocketEvent> pendingSndEvents = pendingSndRcvEvents.getFirst();
        Deque<SocketEvent> pendingRcvEvents = pendingSndRcvEvents.getSecond();

        /*
         * Enqueue SND if there's no RCV event to match with at the moment.
         */
        if( pendingRcvEvents.isEmpty() && !sndRcvPairs.containsKey( String.valueOf(tcpMessageId) ) )
        {
            pendingSndEvents.add( snd );

            return;
        }

        // Add SND event to the (newly created) causal pair and attempt to rebalance its SND/RCV bytes
        String msgId = computeMessageId( snd );
        sndRcvPairs.putIfAbsent(msgId, new MessageCausalPair());
        MessageCausalPair causalPair = sndRcvPairs.get( msgId );
        causalPair.addSnd(snd);

        rebalanceSndRcvCausalPair(causalPair, pendingSndEvents, pendingRcvEvents);

        if(causalPair.isFinished())
        {
            tcpMessageId++;
        }
    }

    /**
     * For an incoming RCV event, the method attempts to pair it with existing SND events in the pending queue. Since the
     * size (in bytes) of the RCV and the existing SND events may not be even, the method iteratively pops pending SND
     * events until matching the full amount of bytes received. If there are no pending SND events, the method adds the
     * incoming RCV to the queue of pending RCV events.
     *
     * @param rcv a RCV event parsed from the event trace.
     * @return void
     */
    private void handleRcvSocketEvent( SocketEvent rcv )
    {
        CausalPair<Deque<SocketEvent>, Deque<SocketEvent>> eventPairs = getOrCreatePartialEventsPairs( rcv.getDirectedSocket() );
        Deque<SocketEvent> pendingSndEvents = eventPairs.getFirst();
        Deque<SocketEvent> pendingRcvEvents = eventPairs.getSecond();

        /*
         * Enqueue RCV if there's no SND event to match with at the moment.
         */
        if( pendingSndEvents.isEmpty() && !sndRcvPairs.containsKey( String.valueOf(tcpMessageId) ) )
        {
            pendingRcvEvents.add( rcv );

            return;
        }

        // Add RCV event to the (newly created) causal pair and attempt to rebalance its SND/RCV bytes
        String msgId = computeMessageId( rcv );
        sndRcvPairs.putIfAbsent(msgId, new MessageCausalPair());
        MessageCausalPair causalPair = sndRcvPairs.get( msgId );
        causalPair.addRcv(rcv);

        rebalanceSndRcvCausalPair(causalPair, pendingSndEvents, pendingRcvEvents);

        if(causalPair.isFinished())
        {
            tcpMessageId++;
        }
    }

    /**
     * Rebalance a SND-RCV causal pair by adding SND or RCV events to it such that the number of bytes sent matches
     * that of bytes received.
     *
     * @param sndRcvPair
     * @param pendingSndEvents
     * @param pendingRcvEvents
     */
    public void rebalanceSndRcvCausalPair(MessageCausalPair sndRcvPair,
                                          Deque<SocketEvent> pendingSndEvents,
                                          Deque<SocketEvent> pendingRcvEvents)
    {
        /*
            We can add events to a SND-RCV causal pair when:
            - there are pending SND events and the pair has more bytes received than sent
            - there are pending RCV events and the pair has more bytes sent than received
         */
        while( (!pendingSndEvents.isEmpty() && sndRcvPair.hasRcvBytesToMatch()) ||
                (!pendingRcvEvents.isEmpty() && sndRcvPair.hasSndBytesToMatch()))
        {
            if(!pendingSndEvents.isEmpty() && sndRcvPair.hasRcvBytesToMatch())
            {
                SocketEvent pendingSnd = pendingSndEvents.pop();
                computeMessageId(pendingSnd);
                sndRcvPair.addSnd(pendingSnd);
            }
            if(!pendingRcvEvents.isEmpty() && sndRcvPair.hasSndBytesToMatch())
            {
                SocketEvent pendingRcv = pendingRcvEvents.pop();
                computeMessageId(pendingRcv);
                sndRcvPair.addRcv(pendingRcv);
            }
        }
    }

    /**
     * Compute the message id for a pair of SND and RCV events.
     *
     */
    public String computeMessageId( SocketEvent... socketEvents )
    {
        String msgId = String.valueOf( tcpMessageId );
        for(int i = 0; i < socketEvents.length; i++)
        {
            socketEvents[i].setMessageId(msgId);
        }

        return msgId;
    }

    /**
     * Combines partitioned SNDs or RCVs into single coarse-grained events.
     *
     * @return void
     */
    public void aggregateAllPartitionedMessages()
    {
        for ( MessageCausalPair pair : sndRcvPairs.values() )
        {
            pair.aggregatePartitionedMessages();
        }
    }

    /**
     * If DEBUG logging level is set, the method prints the data structures maintained by falcon-taz.
     *
     * @return void
     */
    public void printDataStructures()
    {

        StringBuilder debugMsg = new StringBuilder();
        debugMsg.append( "THREAD EVENTS\n" );
        for ( String t : eventsPerThread.keySet() )
        {
            debugMsg.append( "#" + t + "\n" );
            for ( Event e : eventsPerThread.get( t ) )
            {
                debugMsg.append( " " + e.toString() + "\n" );
            }
            debugMsg.append( "\n" );
        }
        logger.debug( debugMsg.toString() );

        debugMsg = new StringBuilder();
        debugMsg.append( "SEND/RECEIVE EVENTS\n" );
        for ( MessageCausalPair se : sndRcvPairs.values() )
        {
            debugMsg.append( se.toString() + "\n" );
        }
        logger.debug( debugMsg.toString() );

        debugMsg = new StringBuilder();
        debugMsg.append( "PENDING SEND/RECEIVE EVENTS\n" );
        for ( Map.Entry<String, CausalPair<Deque<SocketEvent>, Deque<SocketEvent>>> entry : pendingEventsSndRcv.entrySet() )
        {
            if( entry.getValue().getFirst().isEmpty() &&  entry.getValue().getSecond().isEmpty() )
                continue;

            debugMsg.append( "-- Socket " + entry.getKey() + "\n" );

            for ( SocketEvent event : entry.getValue().getFirst() )
                debugMsg.append( event.toString() + "(" + event.getReturnedValue() + ")\n" );

            for ( SocketEvent event : entry.getValue().getSecond() )
                debugMsg.append( event.toString() + "(" + event.getReturnedValue() + ")\n" );
        }
        logger.debug( debugMsg.toString() );

        debugMsg = new StringBuilder();
        debugMsg.append( "MESSAGE HANDLER EVENTS\n" );
        for ( SocketEvent rcv : handlerEvents.keySet() )
        {
            debugMsg.append( "#" + rcv.toString() + "\n" );
            for ( Event e : handlerEvents.get( rcv ) )
            {
                debugMsg.append( " " + e.toString() + "\n" );
            }
        }
        logger.debug( debugMsg.toString() );

        debugMsg = new StringBuilder();
        debugMsg.append( "CONNECT/ACCEPT EVENTS\n" );
        for ( CausalPair<SocketEvent, SocketEvent> se : connAcptEvents.values() )
        {
            debugMsg.append( se.getFirst() + " -> " + se.getSecond() + "\n" );
        }
        logger.debug( debugMsg.toString() );

        debugMsg = new StringBuilder();
        debugMsg.append( "CLOSE/SHUTDOWN EVENTS\n" );
        for ( CausalPair<SocketEvent, SocketEvent> se : closeShutEvents.values() )
        {
            debugMsg.append( se.getFirst() + " -> " + se.getSecond() + "\n" );
        }
        logger.debug( debugMsg.toString() );

        debugMsg = new StringBuilder();
        debugMsg.append( "FORK EVENTS\n" );
        for ( List<ThreadCreationEvent> fset : forkEvents.values() )
        {
            for ( ThreadCreationEvent f : fset )
            {
                debugMsg.append( f.toString() + "\n" );
            }
        }
        logger.debug( debugMsg.toString() );

        debugMsg = new StringBuilder();
        debugMsg.append( "JOIN EVENTS\n" );
        for ( List<ThreadCreationEvent> jset : joinEvents.values() )
        {
            for ( ThreadCreationEvent j : jset )
            {
                debugMsg.append( j.toString() + "\n" );
            }
        }
        logger.debug( debugMsg.toString() );

        debugMsg = new StringBuilder();
        debugMsg.append( "READ/WRITE EVENTS\n" );
        for ( List<RWEvent> rlist : readEvents.values() )
        {
            for ( RWEvent r : rlist )
            {
                debugMsg.append( r.toString() + "\n" );
            }
        }
        for ( List<RWEvent> wlist : writeEvents.values() )
        {
            for ( RWEvent w : wlist )
            {
                debugMsg.append( w.toString() + "\n" );
            }
        }
        logger.debug( debugMsg.toString() );

        debugMsg = new StringBuilder();
        debugMsg.append( "LOCKING EVENTS\n" );
        for ( List<CausalPair<SyncEvent, SyncEvent>> pairs : lockEvents.values() )
        {
            for ( CausalPair<SyncEvent, SyncEvent> p : pairs )
            {
                debugMsg.append( p.toString() + "\n" );
            }
        }
        logger.debug( debugMsg.toString() );

        debugMsg = new StringBuilder();
        debugMsg.append( "WAIT EVENTS\n" );
        for ( List<SyncEvent> wlist : waitEvents.values() )
        {
            for ( SyncEvent w : wlist )
            {
                debugMsg.append( w.toString() + "\n" );
            }
        }
        logger.debug( debugMsg.toString() );

        debugMsg = new StringBuilder();
        debugMsg.append( "NOTIFY EVENTS\n" );
        for ( List<SyncEvent> nlist : notifyEvents.values() )
        {
            for ( SyncEvent n : nlist )
            {
                debugMsg.append( n.toString() + "\n" );
            }
        }
        logger.debug( debugMsg.toString() );

        if ( !sortedByTimestamp.isEmpty() )
        {
            debugMsg = new StringBuilder();
            debugMsg.append( "TIMESTAMP EVENTS\n" );
            for ( Event e : sortedByTimestamp )
            {
                debugMsg.append( e.toString() + "\n" );
            }
            logger.debug( debugMsg.toString() );
        }
    }
}
