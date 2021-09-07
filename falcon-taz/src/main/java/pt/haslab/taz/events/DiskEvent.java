package pt.haslab.taz.events;

import org.json.JSONException;
import org.json.JSONObject;

public class DiskEvent
        extends Event
{

    /* message size (in bytes) */
    int size;

    long fd;

    String filename;

    int returned_value;

    long offset;

    public DiskEvent(String timestamp, EventType type, String thread, int eventNumber, String loc, int size, long fd, long offset, String filename, int return_value)
    {
        super( timestamp, type, thread, eventNumber, loc );
        this.size = size;
        this.fd = fd;
        this.offset = offset;
        this.filename = filename;
        this.returned_value = return_value;
    }

    public DiskEvent( Event e )
    {
        super( e );
        this.size = -1;
        this.offset = -1;
    }


    public int getSize()
    {
        return this.size;
    }

    public void setSize( int size )
    {
        this.size = size;
    }

    public long getFileDescriptor() {
        return fd;
    }

    public void setFileDescriptor(long fd) {
        this.fd = fd;
    }

    public String getFilename() {
        return filename;
    }

    public void setFilename(String filename) {
        this.filename = filename;
    }

    public int getReturnedValue() { return returned_value; }

    public void setReturnedValue(int returned_value) { this.returned_value = returned_value; }

    public long getOffset() {
        return offset;
    }

    public void setOffset(long offset) { this.offset = offset; }

    @Override
    public boolean equals( Object o )
    {
        if ( o == this )
            return true;

        if ( o == null || getClass() != o.getClass() )
            return false;

        DiskEvent tmp = (DiskEvent) o;
        return ( tmp.getThread().equals( this.getThread() )
                && tmp.getEventId() == this.getEventId()
                && tmp.getSize() == this.getSize()
                && tmp.getFileDescriptor() == this.getFileDescriptor()
                && tmp.getFilename().equals(this.getFilename())
                && tmp.getReturnedValue() == this.getReturnedValue()
        );
    }

    @Override
    public String toString()
    {
        String res = this.getType() + "_" + this.getThread() + "_" + this.getEventId();
        return res;
    }

    /**
     * Returns a JSONObject representing the event.
     *
     * @return
     */
    public JSONObject toJSONObject()
            throws JSONException
    {
        JSONObject json = super.toJSONObject();
        json.put( "fd", this.fd );
        json.put( "filename", this.filename );
        if ( this.size >= 0) {
            json.put( "size", this.size );
            json.put("returned_value", this.returned_value);
        }
        if (this.offset >= 0)
            json.put( "offset", this.offset );

        return json;
    }
}
