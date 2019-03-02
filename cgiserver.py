#!/usr/bin/env python

# A tiny CGI server 

# Subclass CGITTPREquestHandler to properly return "Status: XXX" headers and
# non-zero script exit codes.
import BaseHTTPServer, CGIHTTPServer
import sys, os, getopt
from CGIHTTPServer import CGIHTTPRequestHandler
from cStringIO import StringIO

def die(format, *args):
    sys.stderr.write((format+"\r\n") % args)
    sys.exit(1)

class mycgi(CGIHTTPRequestHandler):
    # no special treatment for *.py
    def is_python(self, path):
        return False;
  
    # treat every file as a cgi
    def is_cgi(self):
        self.cgi_info = '', self.path[1:]
        return True

    # log to stdout if not quiet
    def log_message(self, format, *args):
        if not self.quiet: 
            CGIHTTPRequestHandler.log_message(self, format, *args);

    # remember if log_error was invoked
    def log_error(self, format, *args):
        self.error_string=format%args;
        self.log_message(self, format, *args);
        
    # write custom result header
    def wresult(self, s):
        self.wsave.write('%s %s\r\n' % (self.protocol_version, s))

    def run_cgi(self):
        # change file output to StringIO
        self.wsave=self.wfile                 
        self.wfile=StringIO()                     
        self.have_fork=False # CGI must run within this process                    
        self.error_string=None                  
        CGIHTTPRequestHandler.run_cgi(self)    
        self.wfile.seek(0)                    
        # get result status from first line
        status=self.wfile.readline().split(' ')[1].strip();
        # remember possible rewind position
        rewind=self.wfile.tell()
        if status != '200':
            # result is already an error, return verbatim output
            rewind=0
        elif self.error_string is not None:
            # run_cgi invoked log_error, return with status 500 
            self.wresult('500 '+self.error_string)
        else:
            # scan headers for Status: something
            for line in self.wfile:
                if line.strip() == '': 
                    # Not found, return verbatim output
                    rewind=0
                    break
                if line.startswith('Status:'):
                    # Found Status: something, return it instead
                    self.wresult(line.split(':')[1].strip())
                    break
            else:
                # ugh, no line break in output
                self.wresult('500 invalid output')
                
        self.wfile.seek(rewind)
        self.wsave.write(self.wfile.read())

# parse options
try:
    opts, args = getopt.getopt(sys.argv[1:],'r:p:b:l')
    if len(args): raise Exception
except:
    die("""Usage:

    cgiserver.py [options]

Serve cgi scripts via http. Where options are:

    -r root - serve specified root directory, default is current directory
    -p port - listen on specfied port, default is 8000
    -b addr - bind to specified ip address, default is bind to all addresses
    -l      - enable logging to stdout
""")

handler=mycgi;
handler.quiet=True

bind=""
port=8000
for opt, arg in opts:
    if opt == '-r': 
        try:
            os.chdir(arg)
        except:
            die("Invalid root '%s'",arg)

    if opt == '-p': 
        try:
            port=int(arg)
            if not 0<port<65536: raise Exception
        except:
            die("Invalid port '%s'", arg)
    
    if opt == '-b':
        bind=arg
        try:
            if bind.count(".") != 3: raise Exception
            for octet in bind.split('.'):
                if not 0<=int(octet)<=255: raise Exception
        except:
            die("Invalid bind address '%s'", arg);

    if opt == '-l':
        handler.quiet=False

# delete environment
for v in [k for k in os.environ]:
    del os.environ[v]

if not handler.quiet:
    print("Listening for requests on %s port %d in %s..."%("all interfaces" if bind=="" else bind, port, os.getcwd()))

BaseHTTPServer.HTTPServer((bind,port),mycgi).serve_forever()
