<template>
  <link rel="stylesheet" href="html-input-range.css"
  <div id="drawing">
    <div v-if="universe">
      <!-- <button @click="back" :disabled="bigbang">Back</button> -->
      <button @click="tick" :disabled="blackhole">Tick</button>
      <button @click="end" :disabled="blackhole">End</button>
      <form name="registrationForm" align="center">
        <input @click="handleClick" type="range" name="simInputName" class="slider" id="simRangeIn" value="80" min="60" max="100" oninput="simRangeOut.value = simRangeIn.value">
        <output name="simOutputName" id="simRangeOut">80</output>
      </form>
    </div>

    <input type="file" name="file" @change="readFile">
    <h5>Clock: {{ this.clock }}</h5>
  </div>

</template>

<script>
import SVG from 'svg.js';
import EventUniverse from '../core/StorageEventUniverse';
import TraceDrawer from '../core/drawer/StorageTraceDrawer';
import FileReaderPromise from '../core/util/FileReaderPromise';

export default {
  mounted() {
    this.$on('tick', () => {
      this.drawer.nextClock();
    });

    this.drawer = null;
  },
  data() {
    return {
      clock: 0,
      universe: null,
    };
  },
  methods: {
    handleClick() {
      const minSim = document.getElementById('simRangeOut');
      this.drawer.updateDataSimilaritiesByColor(minSim.value);
    },
    tick() {
      this.clock += 1;
      this.$emit('tick', this.clock);
    },
    end() {
      for (this.clock; this.clock < this.universe.maxClock; this.clock += 1) {
        this.$emit('tick', this.clock);
      }
    },
    back() {
      this.clock -= this.clock > 0 ? 1 : 0;
      this.$emit('tick', this.clock);
    },
    readFile(e) {
      const file = e.target.files[0];

      new FileReaderPromise(file).readAsText()
        .then((content) => {
          const jsonContent = JSON.parse(content);
          this.universe = new EventUniverse(jsonContent);
          this.drawer = new TraceDrawer(SVG('drawing'), this.universe);
          this.back();
        });
    },
  },
  computed: {
    bigbang() {
      return this.clock === 0;
    },
    blackhole() {
      const res = this.clock === this.universe.maxClock;
      if (res === true) {
        this.drawer.drawSimilarityInfo();
      }
      return res;
    },
  },
};
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
h1, h2 {
  font-weight: normal;
}

ul {
  list-style-type: none;
  padding: 0;
}

li {
  display: inline-block;
  margin: 0 10px;
}

a {
  color: #42b983;
}

.slider {
  -webkit-appearance: none;
  width: 10%;
  height: 10px;
  border-radius: 4px;
  background: #d3d3d3;
  outline: none;
  opacity: 0.7;
  -webkit-transition: .2s;
  transition: opacity .2s;
}

.slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: #4CAF50;
  cursor: pointer;
}

.slider::-moz-range-thumb {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: #4CAF50;
  cursor: pointer;
}


</style>
