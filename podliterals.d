/* --- */

void main() {
	import std.stdio;
	version (unittest) {
		writeln(`success`);
	} else {
		writeln(`compile with -unittest`);
	};
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
	/* duplicate names are allowed for some reason */
	assert(pod!(X => 1, X => 2).sizeof == (int[2]).sizeof);
};

unittest {
	/* forwarding specs */

	static auto bar(Tº)(Tº Data) {return Data.X;};

	long Foo = 9;
	alias asdf = forward_specs!(bar, X => Foo);
	assert(asdf() == 9);
};

unittest {
	/* ctor */
	static class Cº {
		int X;
		long Y;

		this(Tº)(Tº Data) {
			import std.traits;
			foreach (N; FieldNameTuple!(typeof(this))) {
				__traits(getMember, this, N) = __traits(getMember, Data, N);
			};
		};

		/* forwarding */
		static alias of(Specs...) =
			forward_specs!(Data => new typeof(this)(Data), Specs)
		;
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

/* --- */

auto pod()() @safe pure nothrow @nogc {
	static struct Podº {};
	return Podº();
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

template pod(Specs...) {
	/* ? */

	string spec_ident(size_t Idx)() {
		alias LambTypeº = LambdaType!(Specs[Idx], int);

		static if (is(LambTypeº Fº == delegate)) {
			alias FuncTypeº = Fº;
		} else static if (is(LambTypeº Fº : Fº*)) {
			alias FuncTypeº = Fº;
		} else {
			static assert(0, `field spec #`~Idx.stringof~` is invalid`);
		};

		static if (is(FuncTypeº P == __parameters)) {
			return __traits(identifier, P);
		} else {
			static assert(0, `field spec #`~Idx.stringof~` is invalid`);
		};
	};

	char[] struct_body_str() {
		char[] S;
		foreach (Idx, _; Specs) {
			S ~= `typeof(Specs[`~Idx.stringof~`](0)), "`~spec_ident!Idx~`",`;
		};
		return S;
	};

	char[] instance_body_str() {
		char[] S;
		foreach (Idx, _; Specs) {
			S ~= `Specs[`~Idx.stringof~`](0),`;
		};
		return S;
	};

	auto pod() {
		return mixin(`Podº!(`~struct_body_str~`)(`~instance_body_str~`)`);
	};
};

template pod(Tº, Specs...) if (is(Tº == struct) && __traits(isPOD, Tº)) {
	/* ? */

	string spec_ident(size_t Idx)() {
		alias LambTypeº = LambdaType!(Specs[Idx], int);

		static if (is(LambTypeº Fº == delegate)) {
			alias FuncTypeº = Fº;
		} else static if (is(LambTypeº Fº : Fº*)) {
			alias FuncTypeº = Fº;
		} else {
			static assert(0, `field spec #`~Idx.stringof~` is invalid`);
		};

		static if (is(FuncTypeº P == __parameters)) {
			return __traits(identifier, P);
		} else {
			static assert(0, `field spec #`~Idx.stringof~` is invalid`);
		};
	};

	char[] instance_body_str() {
		char[] S;
		foreach (Idx, _; Specs) {
			S ~= spec_ident!Idx~` : Specs[`~Idx.stringof~`](0),`;
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

/* --- */

private template LambdaType(alias LambTempl, ParamTypesº...) {
	auto f() {return LambTempl!(ParamTypesº);};
	alias LambdaType = typeof(f());
};

private mixin template PodDecls(size_t Idx, Specs...) {
	static if (Idx < Specs.length) {
		mixin(`Specs[`~Idx.stringof~`] `~Specs[Idx + 1]~`;`);
		mixin PodDecls!(Idx + 2, Specs);
	};
};

/* --- */