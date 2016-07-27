/* --- */

void main() {
	import std.stdio;
	version (unittest) {
		writeln(`success`);
	} else {
		writeln(`compile with -unittest`);
	};
};

unittest {	
	import std.stdio;
	import std.meta;
	import std.traits;

	//long b = 6;
	//pragma(msg, pod!(b => .b).b);
};

/* --- */

unittest {
	/* make a struct */
	auto Data = pod!(
		Name => `jeff`,
		Id => 57599538L,
		Alive => true,
	);

	assert(Data.Name == `jeff`);
	assert(Data.Id == long(57599538));
	assert(Data.Alive == true);

	assert(is(typeof(Data) == struct));

	/* access local scope */
	auto More = pod!(
		Nested => Data,
	);

	assert(More.Nested.Alive == true);
	assert(is(typeof(More.Nested) == typeof(Data)));

	/* instanciate existing structures */
	struct Xyzº {
		typeof(More) X;
		wstring Y;
		Object Z;
	};
	auto Thing = pod!(immutable(Xyzº),
		Y => `asdf`w,
		X => More,
		Z => cast(immutable) typeid(Data),
	);

	assert(is(typeof(Thing) == immutable(Xyzº)));
	assert(Thing.Z is typeid(Data));
};

unittest {
	/* type reuse */
	assert(is(typeof(pod!(X => 1)) == typeof(pod!(X => 2))));
	assert(!is(typeof(pod!(X => 1L)) == typeof(pod!(X => 2))));
	assert(!is(typeof(pod!(Y => 1)) == typeof(pod!(X => 2))));
	assert(!is(typeof(pod!(X => 1, Y => 2)) == typeof(pod!(X => 2))));
};

unittest {
	/* empty */
	assert(is(typeof(pod()) == struct));
	assert(is(typeof(pod()) == typeof(pod())));

	/* default vals */
	struct Xyzº {
		Podº!(int, `A`) X;
		wstring Y;
		Object Z;
	};
	assert(is(typeof(pod!Xyzº()) == struct));
};

unittest {
	/* duplicate names are not allowed */
	assert(!__traits(compiles, pod!(X => 1, X => 2)));
};

unittest {
	/* forwarding specs */

	static auto bar(Tº)(Tº Data) {return Data.X;};

	long Foo = 9;
	alias asdf = forward_specs!(bar, X => Foo);
	assert(asdf() == 9);
};

unittest {
	/* class construction */

	struct Util {
		mixin template InitFields(alias Vals) {
			int _ = ({
				import std.traits : FieldNameTuple;
				foreach (X; FieldNameTuple!(typeof(this))) {
					__traits(getMember, this, X) = __traits(getMember, Vals, X);
				};
				return 0;
			})();
		};

		template FromPodSpecs(alias Objº) {
			static alias FromPodSpecs(Specs...) = 
				forward_specs!(Vals => new Objº(Vals), Specs)
			;
		};
	};

	/* ctor */
	static class Cº {
		int X;
		long Y;

		this(Tº)(Tº Data) {
			{mixin Util.InitFields!Data;};
		};

		alias of = Util.FromPodSpecs!(typeof(this));
	};

	/* stack var */
	long Foo = 9;

	/* construct with pod */
	auto Obj = new Cº(pod!(
		Y => Foo,
		X => 1, /* (order reversed) */
	));
	assert(Obj.Y == Foo);

	/* oh yes! */
	Obj = Cº.of!(
		Y => Foo,
		X => 1,
	);
	assert(Obj.Y == Foo);

	/* this might be possible with opAssign or something */
	version (none) {
		Cº Obj2 = pod!(
			Y => Foo,
			X => 1,
		);
		assert(Obj2.Y == Foo);
	};
};

unittest {
	/* making ranges (not good) */

	auto f() {
		auto r = [pod!(
			front => 0,
			empty => false,
			popFront => (void delegate()).init
		)].ptr;
		r.popFront = {r.empty = ++r.front == 7;};
		return r;
	};

	import std.range;
	assert(isInputRange!(typeof(f())));

	// import std.array;
	// assert(f().array == [0, 1, 2, 3, 4, 5, 6]); // fail

	// foreach (x; f()) { // fail

	/* better */
	auto g() {
		int Elem;
		return new class {
			@property int front() {return Elem;};
			bool empty;
			void popFront() {
				empty = ++Elem == 7;
			};
		};
	};

	assert(isInputRange!(typeof(g())));

	import std.array;
	assert(g().array == [0, 1, 2, 3, 4, 5, 6]);
};

/* --- */

auto pod()() @safe pure nothrow @nogc {
	return Podº!()();
};

template pod(Specs...) {
	/* ? */

	char[] struct_body_str() {
		char[] S;
		foreach (Idx, _; Specs) {
			S ~= `typeof(Specs[`~Idx.stringof~`]((void[0]).init)), `;
			S ~= `"`~pod_spec_ident!(Idx, Specs)~`", `;
		};
		return S;
	};

	auto pod() {
		mixin(`alias Tº = Podº!(`~struct_body_str~`);`);
		return pod!(Tº, Specs);
	};
};

template pod(Tº, Specs...) if (is(Tº == struct) && __traits(isPOD, Tº)) {
	/* ? */

	char[] instance_body_str() {
		char[] S;
		foreach (Idx, _; Specs) {
			S ~= pod_spec_ident!(Idx, Specs)~` : `;
			S ~= `Specs[`~Idx.stringof~`]((void[0]).init),`;
		};
		return S;
	};

	auto pod() {
		mixin(`Tº Obj = {`~instance_body_str~`};`);
		return Obj;
		static assert(is(typeof(Obj) == Tº));
	};
};

auto forward_specs(alias f, Specs...)() {
	return f(pod!Specs);
};

struct Podº(Specs...) if (Specs.length % 2 == 0) {
	/* Specs: (type0, `name0`, type1, `name1`, ...) */
	mixin PodDecls!(0, Specs);
	static assert(__traits(isPOD, typeof(this)));
};
unittest {
	assert(is(Podº!(int, `x`) == Podº!(int, `x`)));
	assert(is(typeof(Podº!(int, `x`).x) == int));
	assert(is(Podº!(int, `x`, Object, `y`) == Podº!(int, `x`, Object, `y`)));
	assert(!is(Podº!(int, `x`, TypeInfo, `y`) == Podº!(int, `x`, Object, `y`)));
	assert(!is(Podº!(int, `x`, Object, `z`) == Podº!(int, `x`, Object, `y`)));
	assert([__traits(allMembers, Podº!(int, `x`, int, `z`))] == [`x`, `z`]);
};

/* --- */

private template LambdaType(alias LambdaTemplate, ParamTypesº...) {
	auto f() {return LambdaTemplate!(ParamTypesº);};
	alias LambdaType = typeof(f());
};

private mixin template PodDecls(size_t Idx, Specs...) {
	static if (Idx < Specs.length) {
		mixin(`Specs[`~Idx.stringof~`] `~Specs[Idx + 1]~`;`);
		mixin PodDecls!(Idx + 2, Specs);
	};
};

private string pod_spec_ident(size_t Idx, Specs...)() {
	enum int Idx1 = Idx + 1;
	enum Err = `field spec #`~Idx1.stringof~` is invalid`;

	static assert(__traits(isTemplate, Specs[Idx]), Err);

	alias RawTypeº = LambdaType!(Specs[Idx], void[0]);

	static if (is(RawTypeº Fº == delegate)) {
		alias FuncTypeº = Fº;
	} else static if (is(RawTypeº Fº : Fº*)) {
		alias FuncTypeº = Fº;
	} else {
		static assert(0, Err);
	};

	static if (is(FuncTypeº P == __parameters)) {
		return __traits(identifier, P);
	} else {
		static assert(0, Err);
	};
};

/* --- */
