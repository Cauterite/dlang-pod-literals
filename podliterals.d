/* --- */

unittest {
	/* make a struct */
	immutable Data = pod!(
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
	auto Inf = float.infinity;

	/* union */
	auto U = pod!(
		(string X) => null,
		(float Z) => Inf,
		(long* Y) => null,
	);

	assert(U.X.length == 0x7F800000);
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
	auto EmptyPod = pod!();
	assert(EmptyPod is pod!());
	assert(is(typeof(pod!()) == struct));
	assert(is(typeof(pod!()) == typeof(pod!())));
	import std.traits : FieldNameTuple;
	assert(FieldNameTuple!(typeof(pod!())).length == 0);

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
	alias asdf = forward_pod!(bar, X => Foo);
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
				forward_pod!(Vals => new Objº(Vals), Specs)
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

unittest {
	/* the shadowing problem: */
	static assert(!__traits(compiles, {
		int Id = 2;
		auto Data = pod!(
			Name => `jeff`,
			Id => Id, // whoops
			Alive => true,
		);
	}));

	{/* the workaround */
		int Id = 2;
		auto Data = pod!(
			Name => `jeff`,
			Id· => Id, /* ALT+0183 */
			Alive => true,
		);
		assert(Data.Id == Id);
	};
};

/* --- */

enum pod() = Podº!()();

auto pod(Specs...)() if (__traits(isTemplate, Specs)) {
	/* structure-type POD */

	dchar[] StructBodyStr() {
		dchar[] S;
		foreach (Idx, _; Specs) {
			S ~= `typeof(Specs[`~Idx.stringof~`](Poisonº.init)), `d;
			S ~= `"`~PodSpecIdent!(Specs[Idx], Idx)~`", `d;
		};
		return S;
	};

	mixin(`alias Tº = Podº!(`~StructBodyStr~`);`);
	return pod!(Tº, Specs);
};

auto pod(Specs...)() if (!__traits(isTemplate, Specs)) {
	/* union-type POD */

	alias Q(size_t Idx) = UnionSpecInfo!(Specs[Idx], Idx);

	dchar[] UnionBodyStr() {
		dchar[] S;
		foreach (Idx, _; Specs) {
			S ~= `Q!`~Idx.stringof~`.ParamTypeº, "`~Q!Idx.ParamName~`", `d;
		};
		return S;
	};

	dchar[] InstanceBodyStr() {
		dchar[] S;
		foreach (Idx, _; Specs) {
			if (is(Q!Idx.RetTypeº == typeof(null))) {continue;};
			/* `ParamName : Specs[Idx](ParamTypeº.init),` */
			S ~= Q!Idx.ParamName~` : `d;
			enum I = Idx.stringof;
			S ~= `Specs[`~I~`](Q!(`~I~`).ParamTypeº.init),`d;
		};
		return S;
	};

	mixin(`alias Tº = PodUnionº!(`~UnionBodyStr~`);`);
	mixin(`Tº Obj = {`~InstanceBodyStr~`};`);
	return Obj;
	static assert(__traits(isPOD, Tº));
};

auto pod(Tº, Specs...)() if (is(Tº == struct) && __traits(isPOD, Tº)) {
	/* instanciate POD from existing structure type */

	dchar[] InstanceBodyStr() {
		dchar[] S;
		foreach (Idx, _; Specs) {
			S ~= PodSpecIdent!(Specs[Idx], Idx)~` : `d;
			S ~= `Specs[`~Idx.stringof~`](Poisonº.init),`d;
		};
		return S;
	};

	mixin(`Tº Obj = {`~InstanceBodyStr~`};`);
	return Obj;
	static assert(is(typeof(Obj) == Tº));
};

auto forward_pod(alias f, Specs...)() {
	return f(pod!Specs);
};

struct Podº(Specs...) if (Specs.length % 2 == 0) {
	/* Specs: (type0, `name0`, type1, `name1`, ...) */
	mixin PodDecls!(0, Specs);
	static assert(__traits(isPOD, typeof(this)));
};
union PodUnionº(Specs...) if (Specs.length % 2 == 0) {
	/* Specs: (type0, `name0`, type1, `name1`, ...) */
	mixin PodDecls!(0, Specs);
	static assert(__traits(isPOD, typeof(this)));
};
unittest {
	assert(is(Podº!(int, `x`) == Podº!(int, `x`)));
	assert(is(PodUnionº!(int, `x`) == PodUnionº!(int, `x`)));
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

private template PodSpecIdent(alias Spec, size_t Idx) {
	static if (
		__traits(isTemplate, Spec) &&
		is(LambdaType!(Spec, void[0]) Rawº) &&
		(is(Rawº Fº == delegate) || is(Rawº Fº : Fº*)) &&
		is(Fº P == __parameters)
	) {
		enum PodSpecIdent = __traits(identifier, P).strip_ident_padding;
	} else {
		enum int Idx1 = Idx + 1;
		static assert(0, `field spec #`~Idx1.stringof~` is invalid`);
	};
};

private template UnionSpecInfo(alias Spec, size_t Idxª) {
	static if (
		is(typeof(Spec) Rawº) &&
		(is(Rawº Fº == delegate) || is(Rawº Fº : Fº*)) &&
		is(Fº Pº == function) &&
		is(Fº P == __parameters) &&
		is(Fº Rº == return)
	) {
		struct UnionSpecInfo {
			enum Idx = Idxª;
			enum ParamName = __traits(identifier, P).strip_ident_padding;
			alias ParamTypeº = Pº[0];
			alias RetTypeº = Rº;
		};
	} else {
		enum int Idx1 = Idxª + 1;
		static assert(0, `field spec #`~Idx1.stringof~` is invalid`);
	};
};

/* pad character which can be lead or trail POD-spec identifiers.
exists to solve the shadowing problem. */
private enum dchar Pad = dchar(183); /* middle dot */
private dstring strip_ident_padding(dstring S) {
	while (S && S[$ - 1] == Pad) {S = S[0 .. $ - 1];};
	while (S && S[0] == Pad) {S = S[1 .. $];};
	assert(S != ``);
	return S;
};
unittest {
	static if (Pad == '·') {
		alias f = strip_ident_padding;
		assert(f(`···foo·····`) == `foo`);
		assert(f(`···foo`) == `foo`);
		assert(f(`·foo`) == `foo`);
		assert(f(`·foo·`) == `foo`);
		assert(f(`foo····`) == `foo`);
		assert(f(`foo`) == `foo`);
		assert(f(`···x····`) == `x`);
		assert(f(`x`) == `x`);
	};
};

/* this is the type fed into the lambdas of POD-specs.
it's designed to catch the common mistake of shadowing local variable references
in the body of the lambda:
	int x = 1;
	pod!(x => x); // ERROR

however we can't detect this mistake for union literals */
private alias Poisonº = POD_FIELD_NAME_SHADOWING_LAMBDA_BODY;
private struct POD_FIELD_NAME_SHADOWING_LAMBDA_BODY {
	@disable this();
	@disable this(this);
	@disable this(typeof(this));
	@disable void opAssign(in ref typeof(this));
};

/* --- */
