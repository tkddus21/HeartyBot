# def mygen():
#     yield'a'
#     yield'b'
#     yield'c'

# g = mygen()

# print(type(g))

# next(g)
# next(g)
# next(g)

def mygen():
    for i in range(1, 1000):
        result = i * i 
        yield result

gen = mygen()

# gen = (i*i for i in range(1, 1000))

print(next(gen))
print(next(gen))
print(next(gen))