package com.example.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@RestController
public class LoadController {

    private final List<byte[]> memoryLeak = new ArrayList<>();
    private final ExecutorService executor = Executors.newFixedThreadPool(4);

    @GetMapping("/")
    public String hello() {
        return "Hello from Pyroscope Demo App! Try /cpu or /memory";
    }

    // Simula carga de CPU: calcula números primos o Fibonacci de forma ineficiente
    @GetMapping("/cpu")
    public String cpuLoad(@RequestParam(defaultValue = "100000") int iterations) {
        long start = System.currentTimeMillis();
        executor.submit(() -> {
            Random random = new Random();
            for (int i = 0; i < iterations; i++) {
                Math.tan(Math.atan(Math.tan(Math.atan(random.nextDouble()))));
            }
        });
        return "CPU load started for " + iterations + " iterations.";
    }

    // Simula carga de CPU sincrona para ver en el flamegraph del request
    @GetMapping("/cpu-sync")
    public String cpuLoadSync(@RequestParam(defaultValue = "35") int n) {
        long start = System.currentTimeMillis();
        long result = fibonacci(n);
        long duration = System.currentTimeMillis() - start;
        return "Fibonacci(" + n + ") = " + result + " calculated in " + duration + "ms";
    }

    private long fibonacci(int n) {
        if (n <= 1) return n;
        return fibonacci(n - 1) + fibonacci(n - 2);
    }

    // Simula fuga de memoria
    @GetMapping("/memory")
    public String memoryLeak(@RequestParam(defaultValue = "10") int mb) {
        // Allocate MBs
        byte[] bytes = new byte[mb * 1024 * 1024];
        memoryLeak.add(bytes);
        return "Allocated " + mb + "MB. Total list size: " + memoryLeak.size();
    }
    
    @GetMapping("/memory-clear")
    public String memoryClear() {
        memoryLeak.clear();
        System.gc();
        return "Memory cleared.";
    }
}
