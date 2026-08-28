AR ?= ar
OBJECTS := alpha.o beta.o

libdemo.a: $(OBJECTS)
	$(AR) rcs $@ $(OBJECTS)

clean:
	rm -f $(OBJECTS) libdemo.a
