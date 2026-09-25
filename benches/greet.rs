//! Benchmarks for [`rust_template::greet`], run with `cargo bench` (`make bench`).
//!
//! criterion measures each function many times and reports the spread and
//! the change since the last run; the HTML report lands in
//! `target/criterion/report/index.html`. Replace these with benchmarks of
//! your own hot paths.

use std::hint::black_box;

use criterion::{Criterion, criterion_group, criterion_main};
use rust_template::greet::greeting;

fn bench_greeting(c: &mut Criterion) {
    c.bench_function("greeting", |b| b.iter(|| greeting(black_box("Ferris"), black_box(false))));
    c.bench_function("greeting shout", |b| {
        b.iter(|| greeting(black_box("Ferris"), black_box(true)));
    });
}

criterion_group!(benches, bench_greeting);
criterion_main!(benches);
