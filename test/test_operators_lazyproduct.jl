using Base.Test
using QuantumOptics


@testset "operators-lazyproduct" begin

srand(0)

D(op1::Operator, op2::Operator) = abs(tracedistance_general(full(op1), full(op2)))
D(x1::StateVector, x2::StateVector) = norm(x2-x1)
randop(bl, br) = DenseOperator(bl, br, rand(Complex128, length(bl), length(br)))
randop(b) = randop(b, b)
sprandop(bl, br) = sparse(DenseOperator(bl, br, rand(Complex128, length(bl), length(br))))
sprandop(b) = sprandop(b, b)

b1a = GenericBasis(2)
b1b = GenericBasis(3)
b2a = GenericBasis(1)
b2b = GenericBasis(4)
b3a = GenericBasis(1)
b3b = GenericBasis(5)

b_l = b1a⊗b2a⊗b3a
b_r = b1b⊗b2b⊗b3b

# Test creation
@test_throws AssertionError LazyProduct()
@test_throws AssertionError LazyProduct(randop(b_l, b_r), randop(b_l, b_r))
@test_throws AssertionError LazyProduct(randop(b_l, b_r), sparse(randop(b_l, b_r)))

# Test full & sparse
op1 = randop(b_l, b_r)
op2 = sparse(randop(b_r, b_l))
@test 0.1*(op1*full(op2)) == full(LazyProduct([op1, op2], 0.1))
@test 0.1*(sparse(op1)*op2) == sparse(LazyProduct([op1, op2], 0.1))


# Arithmetic operations
# =====================
op1a = randop(b_l, b_r)
op1b = randop(b_r, b_l)
op2a = randop(b_l, b_r)
op2b = randop(b_r, b_l)
op3a = randop(b_l, b_l)
op1 = LazyProduct([op1a, sparse(op1b)])*0.1
op1_ = 0.1*(op1a*op1b)
op2 = LazyProduct([sparse(op2a), op2b], 0.3)
op2_ = 0.3*(op2a*op2b)
op3 = LazyProduct(op3a)
op3_ = op3a

x1 = Ket(b_l, rand(Complex128, length(b_l)))
x2 = Ket(b_l, rand(Complex128, length(b_l)))
xbra1 = Bra(b_l, rand(Complex128, length(b_l)))
xbra2 = Bra(b_l, rand(Complex128, length(b_l)))

# Addition
@test_throws ArgumentError op1 + op2
@test 1e-14 > D(-op1_, -op1)

# Test multiplication
@test_throws bases.IncompatibleBases op1a*op1a
@test 1e-11 > D(op1*(x1 + 0.3*x2), op1_*(x1 + 0.3*x2))
@test 1e-11 > D((xbra1 + 0.3*xbra2)*op1, (xbra1 + 0.3*xbra2)*op1_)
@test 1e-11 > D(op1*x1 + 0.3*op1*x2, op1_*x1 + 0.3*op1_*x2)
@test 1e-12 > D(dagger(x1)*dagger(0.3*op2), dagger(x1)*dagger(0.3*op2_))

# Test division
@test 1e-14 > D(op1/7, op1_/7)

# Test identityoperator
Idense = identityoperator(DenseOperator, b_l)
I = identityoperator(LazyProduct, b_l)
@test isa(I, LazyProduct)
@test full(I) == Idense
@test 1e-11 > D(I*x1, x1)
@test 1e-11 > D(xbra1*I, xbra1)

# Test trace and normalize
op1 = randop(b_l)
op2 = randop(b_l)
op = LazyProduct(op1, op2)
@test_throws ArgumentError trace(op)
@test_throws ArgumentError ptrace(op, [1, 2])
@test_throws ArgumentError normalize(op)
@test_throws ArgumentError normalize!(op)

# Test expect
op1 = randop(b_l)
op2 = randop(b_l)
op = 0.3*LazyProduct(op1, sparse(op2))
op_ = 0.3*op1*op2

state = Ket(b_l, rand(Complex128, length(b_l)))
@test expect(op, state) ≈ expect(op_, state)

state = DenseOperator(b_l, b_l, rand(Complex128, length(b_l), length(b_l)))
@test expect(op, state) ≈ expect(op_, state)

# Permute systems
op1 = randop(b_l)
op2 = randop(b_l)
op3 = randop(b_l)
op = 0.3*LazyProduct(op1, op2, sparse(op3))
op_ = 0.3*op1*op2*op3

@test 1e-14 > D(permutesystems(op, [1, 3, 2]), permutesystems(op_, [1, 3, 2]))
@test 1e-14 > D(permutesystems(op, [2, 1, 3]), permutesystems(op_, [2, 1, 3]))
@test 1e-14 > D(permutesystems(op, [2, 3, 1]), permutesystems(op_, [2, 3, 1]))
@test 1e-14 > D(permutesystems(op, [3, 1, 2]), permutesystems(op_, [3, 1, 2]))
@test 1e-14 > D(permutesystems(op, [3, 2, 1]), permutesystems(op_, [3, 2, 1]))


# Test gemv
op1 = randop(b_l, b_r)
op2 = randop(b_r, b_l)
op3 = randop(b_l, b_r)
op = LazyProduct([op1, sparse(op2), op3], 0.2)
op_ = 0.2*op1*op2*op3

state = Ket(b_r, rand(Complex128, length(b_r)))
result_ = Ket(b_l, rand(Complex128, length(b_l)))
result = deepcopy(result_)
operators.gemv!(complex(1.), op, state, complex(0.), result)
@test 1e-13 > D(result, op_*state)

result = deepcopy(result_)
alpha = complex(1.5)
beta = complex(2.1)
operators.gemv!(alpha, op, state, beta, result)
@test 1e-13 > D(result, alpha*op_*state + beta*result_)

state = Bra(b_l, rand(Complex128, length(b_l)))
result_ = Bra(b_r, rand(Complex128, length(b_r)))
result = deepcopy(result_)
operators.gemv!(complex(1.), state, op, complex(0.), result)
@test 1e-13 > D(result, state*op_)

result = deepcopy(result_)
alpha = complex(1.5)
beta = complex(2.1)
operators.gemv!(alpha, state, op, beta, result)
@test 1e-13 > D(result, alpha*state*op_ + beta*result_)

# Test gemm
op1 = randop(b_l, b_r)
op2 = randop(b_r, b_l)
op3 = randop(b_l, b_r)
op = LazyProduct([op1, sparse(op2), op3], 0.2)
op_ = 0.2*op1*op2*op3

state = randop(b_r, b_r)
result_ = randop(b_l, b_r)
result = deepcopy(result_)
operators.gemm!(complex(1.), op, state, complex(0.), result)
@test 1e-11 > D(result, op_*state)

result = deepcopy(result_)
alpha = complex(1.5)
beta = complex(2.1)
operators.gemm!(alpha, op, state, beta, result)
@test 1e-11 > D(result, alpha*op_*state + beta*result_)

state = randop(b_l, b_l)
result_ = randop(b_l, b_r)
result = deepcopy(result_)
operators.gemm!(complex(1.), state, op, complex(0.), result)
@test 1e-11 > D(result, state*op_)

result = deepcopy(result_)
alpha = complex(1.5)
beta = complex(2.1)
operators.gemm!(alpha, state, op, beta, result)
@test 1e-11 > D(result, alpha*state*op_ + beta*result_)

end # testset