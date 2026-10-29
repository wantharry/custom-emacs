import { Component } from '@angular/core';

@Component({
  selector: 'app-fixture',
  template: '<p>{{ name }}</p>'
})
export class FixtureComponent {
  name = 'fixture';
}
